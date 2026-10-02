// Supabase Edge Function: calculate-route
// Secrets required: GOOGLE_ROUTES_API_KEY
// Deploy with: supabase functions deploy calculate-route

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (request) => {
  if (request.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const { stops } = await request.json();
  if (!Array.isArray(stops) || stops.length < 2 || stops.length > 25) {
    return Response.json({ error: "Provide between 2 and 25 stops" }, { status: 400 });
  }

  const key = Deno.env.get("GOOGLE_ROUTES_API_KEY");
  if (!key) return Response.json({ error: "Route provider is not configured" }, { status: 503 });

  const waypoints = stops.slice(1, -1).map((stop: { latitude: number; longitude: number }) => ({
    location: { latLng: { latitude: stop.latitude, longitude: stop.longitude } },
  }));
  const body = {
    origin: { location: { latLng: { latitude: stops[0].latitude, longitude: stops[0].longitude } } },
    destination: { location: { latLng: { latitude: stops[stops.length - 1].latitude, longitude: stops[stops.length - 1].longitude } } },
    intermediates: waypoints,
    travelMode: "DRIVE",
    routingPreference: "TRAFFIC_UNAWARE",
    optimizeWaypointOrder: false,
  };

  const googleResponse = await fetch("https://routes.googleapis.com/directions/v2:computeRoutes", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": key,
      "X-Goog-FieldMask": "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline",
    },
    body: JSON.stringify(body),
  });

  if (!googleResponse.ok) {
    return Response.json({ error: "Route provider failed" }, { status: 502 });
  }
  const result = await googleResponse.json();
  const route = result.routes?.[0];
  if (!route) return Response.json({ error: "No route found" }, { status: 404 });

  return Response.json({
    durationSeconds: Number.parseInt(String(route.duration ?? "0").replace("s", ""), 10),
    distanceMeters: route.distanceMeters ?? 0,
    encodedPolyline: route.polyline?.encodedPolyline ?? "",
  });
});
