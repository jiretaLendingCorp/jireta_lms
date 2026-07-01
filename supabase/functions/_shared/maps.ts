// supabase/functions/_shared/maps.ts

const GEOCODE_BASE = 'https://maps.googleapis.com/maps/api/geocode/json';

function getApiKey(): string {
  const key = Deno.env.get('GOOGLE_MAPS_API_KEY');
  if (!key) throw new Error('GOOGLE_MAPS_API_KEY not configured');
  return key;
}

export interface GeocodeResult {
  lat: number;
  lng: number;
  formattedAddress: string;
}

export async function geocodeAddress(address: string): Promise<GeocodeResult | null> {
  const key = Deno.env.get('GOOGLE_MAPS_API_KEY');
  if (!key) {
    console.warn('GOOGLE_MAPS_API_KEY not configured — skipping geocoding fallback');
    return null;
  }

  try {
    const params = new URLSearchParams({
      address: `${address}, Philippines`,
      key,
      region: 'ph',
    });

    const res = await fetch(`${GEOCODE_BASE}?${params.toString()}`);
    const data = await res.json();

    if (data.status !== 'OK' || !data.results?.length) {
      console.warn('Geocoding failed:', data.status, address);
      return null;
    }

    const result = data.results[0];
    return {
      lat: result.geometry.location.lat,
      lng: result.geometry.location.lng,
      formattedAddress: result.formatted_address,
    };
  } catch (e) {
    console.error('Geocoding exception:', e);
    return null;
  }
}

export function staticMapUrl(lat: number, lng: number, opts?: {
  zoom?: number;
  width?: number;
  height?: number;
}): string {
  const key = getApiKey();
  const params = new URLSearchParams({
    center: `${lat},${lng}`,
    zoom: String(opts?.zoom ?? 15),
    size: `${opts?.width ?? 600}x${opts?.height ?? 400}`,
    markers: `color:red|${lat},${lng}`,
    key,
  });
  return `https://maps.googleapis.com/maps/api/staticmap?${params.toString()}`;
}

export function navigationUrl(lat: number, lng: number): string {
  return `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}&travelmode=driving`;
}