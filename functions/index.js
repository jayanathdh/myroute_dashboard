/**
 * Cloud Functions (Node.js 22)
 * - linkStopToGoogle (Callable, Gen2) + Secret GOOGLE_PLACES_KEY
 * - sendNotificationOnCreate (Firestore trigger, Gen2)
 */

const admin = require("firebase-admin");
admin.initializeApp();

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");

/**
 * ✅ Callable (Gen2): linkStopToGoogle
 * Input: { stopId: "kurunegala" }
 * Requires:
 * - Firestore: bus_stops/{stopId} with location.lat & location.lng as numbers
 * - Secret: GOOGLE_PLACES_KEY (Google Places API key)
 */
exports.linkStopToGoogle = onCall(
  { region: "us-central1", secrets: ["GOOGLE_PLACES_KEY"] },
  async (request) => {
    try {
      const data = request.data || {};
      const stopId = data.stopId ? String(data.stopId) : "";
      if (!stopId) throw new HttpsError("invalid-argument", "Missing stopId");

      const apiKey = process.env.GOOGLE_PLACES_KEY;
      if (!apiKey) throw new HttpsError("failed-precondition", "Missing GOOGLE_PLACES_KEY secret");

      const stopRef = admin.firestore().collection("bus_stops").doc(stopId);
      const stopSnap = await stopRef.get();

      if (!stopSnap.exists) throw new HttpsError("not-found", "Stop not found");

      const stop = stopSnap.data() || {};
      const loc = stop.location;

      if (!loc || typeof loc.lat !== "number" || typeof loc.lng !== "number") {
        throw new HttpsError(
          "failed-precondition",
          "Stop has no valid GPS (location.lat, location.lng)"
        );
      }

      const radius = 300; // meters

      async function nearby(type) {
        const url =
          "https://maps.googleapis.com/maps/api/place/nearbysearch/json" +
          `?location=${loc.lat},${loc.lng}` +
          `&radius=${radius}` +
          `&type=${type}` +
          `&key=${encodeURIComponent(apiKey)}`;

        const res = await fetch(url);
        return await res.json();
      }

      // 1) Try bus_station
      let json = await nearby("bus_station");

      // 2) Fallback: transit_station
      if (!json || json.status !== "OK" || !Array.isArray(json.results) || json.results.length === 0) {
        json = await nearby("transit_station");
      }

      // No results
      if (!json || json.status !== "OK" || !Array.isArray(json.results) || json.results.length === 0) {
        return { placeId: null, status: json?.status || "NO_RESULTS" };
      }

      const best = json.results[0];
      const placeId = best.place_id;

      await saveGoogleLink(stopRef, stopId, best, placeId);

      return { placeId, status: "OK" };
    } catch (err) {
      if (err instanceof HttpsError) throw err;
      console.error("linkStopToGoogle error:", err);
      throw new HttpsError("internal", "Internal error");
    }
  }
);

async function saveGoogleLink(stopRef, stopId, best, placeId) {
  const geo = best?.geometry?.location ?? null;

  // 1) Update manual stop doc
  await stopRef.update({
    google_place_id: placeId,
    google_linked_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2) Save google cache doc
  await admin.firestore().collection("bus_stops_google").doc(placeId).set(
    {
      place_id: placeId,
      name: best?.name ?? null,
      type: Array.isArray(best?.types) && best.types.length ? best.types[0] : null,
      location: geo ? { lat: geo.lat, lng: geo.lng } : null,
      manual_stop_id: stopId,
      source: "google_places_nearby",
      fetched_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/**
 * ✅ Firestore Trigger (Gen2): sendNotificationOnCreate
 * Trigger: notifications/{docId} created
 */
exports.sendNotificationOnCreate = onDocumentCreated(
  { region: "us-central1", document: "notifications/{docId}" },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const data = snapshot.data() || {};

    const title = data.title || "";
    const body = data.description || "";
    const image = data.image || "";

    const payload = {
      notification: {
        title,
        body,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        title,
        body,
        image,
      },
      topic: "news",
    };

    if (image) {
      payload.notification.image = image;
    }

    try {
      await admin.messaging().send(payload);
      console.log("Notification sent successfully:", title);
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  }
);
// Add this code to: functions/index.js
// Required: npm install @google/genai

const { GoogleGenAI } = require('@google/genai');

const { defineSecret } = require('firebase-functions/params');

const geminiApiKey = defineSecret('GEMINI_API_KEY');

const timetableSchema = {
  type: 'object',
  properties: {
    routeNo: { type: 'string' },
    from: { type: 'string' },
    to: { type: 'string' },
    routeType: { type: 'string', enum: ['Normal Route', 'Express Route', 'Intercity Route', 'School Route'] },
    roadType: { type: 'string', enum: ['Normal Road', 'Highway', 'Expressway', 'Mixed'] },
    busType: { type: 'string', enum: ['Normal', 'Semi Luxury', 'Luxury', 'Super Luxury', 'Express'] },
    dayType: { type: 'string', enum: ['Every Day', 'Weekdays', 'Saturday', 'Sunday', 'Holiday'] },
    departureTimes: { type: 'array', items: { type: 'string' } },
  },
  required: ['routeNo', 'from', 'to', 'routeType', 'roadType', 'busType', 'dayType', 'departureTimes'],
};

const acceptedMimeTypes = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  pdf: 'application/pdf',
};

exports.analyzeTimetable = onCall(
  {
    region: 'asia-south1',
    timeoutSeconds: 120,
    memory: '1GiB',
    secrets: [geminiApiKey],
  },
  async (request) => {
    const data = request.data || {};
    const fileUrl = typeof data.fileUrl === 'string' ? data.fileUrl : '';
    const fileExtension = typeof data.fileExtension === 'string'
      ? data.fileExtension.toLowerCase()
      : '';
    const prompt = typeof data.prompt === 'string' ? data.prompt.trim() : '';
    const fallback = asObject(data.fallback);

    if (!fileUrl.startsWith('https://firebasestorage.googleapis.com/')) {
      throw new HttpsError('invalid-argument', 'A Firebase Storage download URL is required.');
    }

    const mimeType = acceptedMimeTypes[fileExtension];
    if (!mimeType) {
      throw new HttpsError('invalid-argument', 'Only image and PDF files can be analyzed currently.');
    }

    const fileResponse = await fetch(fileUrl);
    if (!fileResponse.ok) {
      throw new HttpsError('not-found', 'The uploaded timetable could not be downloaded.');
    }
    const base64File = Buffer.from(await fileResponse.arrayBuffer()).toString('base64');

    const ai = new GoogleGenAI({ apiKey: geminiApiKey.value() });
    const result = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: [{
        role: 'user',
        parts: [
          { inlineData: { data: base64File, mimeType } },
          { text: extractionPrompt(prompt, fallback) },
        ],
      }],
      config: {
        responseMimeType: 'application/json',
        responseJsonSchema: timetableSchema,
        temperature: 0,
      },
    });

    try {
      return normalizeResult(JSON.parse(result.text || ''), fallback);
    } catch (_) {
      throw new HttpsError('internal', 'The AI response could not be read as timetable data.');
    }
  },
);

function extractionPrompt(prompt, fallback) {
  return `You extract data from Sri Lankan bus timetable images and PDF documents.
Return only the requested JSON schema. Do not invent missing information.

Extract: route number, origin (from), destination (to), route type, road type,
bus type, day type, and every departure time. Normalize times to 24-hour HH:mm.
Use a supplied fallback only when the timetable does not state that value.

Admin instruction: ${prompt || '(none)'}
Fallback values: ${JSON.stringify(fallback)}`;
}

function normalizeResult(extracted, fallback) {
  const text = (key) => String(extracted[key] || fallback[key] || '').trim();
  const departureTimes = Array.isArray(extracted.departureTimes)
    ? extracted.departureTimes.map((time) => String(time).trim()).filter(Boolean)
    : [];

  return {
    routeNo: text('routeNo'),
    from: text('from'),
    to: text('to'),
    routeType: choice(text('routeType'), ['Normal Route', 'Express Route', 'Intercity Route', 'School Route'], 'Normal Route'),
    roadType: choice(text('roadType'), ['Normal Road', 'Highway', 'Expressway', 'Mixed'], 'Normal Road'),
    busType: choice(text('busType'), ['Normal', 'Semi Luxury', 'Luxury', 'Super Luxury', 'Express'], 'Normal'),
    dayType: choice(text('dayType'), ['Every Day', 'Weekdays', 'Saturday', 'Sunday', 'Holiday'], 'Every Day'),
    departureTimes,
  };
}

function choice(value, values, defaultValue) {
  return values.includes(value) ? value : defaultValue;
}

function asObject(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
}
