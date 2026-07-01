// supabase/functions/_shared/encryption.ts

const ALGORITHM = 'AES-GCM';
const KEY_LENGTH = 256;
const IV_LENGTH = 12;

async function getKey(): Promise<CryptoKey> {
  const keyMaterial = Deno.env.get('AES_ENCRYPTION_KEY');
  if (!keyMaterial) throw new Error('AES_ENCRYPTION_KEY not set');

  const raw = hexToBytes(keyMaterial);
  return await crypto.subtle.importKey(
    'raw',
    raw,
    { name: ALGORITHM, length: KEY_LENGTH },
    false,
    ['encrypt', 'decrypt'],
  );
}

export async function encrypt(plaintext: string): Promise<string> {
  const key = await getKey();
  const iv = crypto.getRandomValues(new Uint8Array(IV_LENGTH));
  const encoded = new TextEncoder().encode(plaintext);

  const ciphertext = await crypto.subtle.encrypt(
    { name: ALGORITHM, iv },
    key,
    encoded,
  );

  const combined = new Uint8Array(iv.length + ciphertext.byteLength);
  combined.set(iv, 0);
  combined.set(new Uint8Array(ciphertext), iv.length);

  return btoa(String.fromCharCode(...combined));
}

export async function decrypt(encryptedB64: string): Promise<string> {
  const key = await getKey();
  const combined = Uint8Array.from(atob(encryptedB64), (c) => c.charCodeAt(0));

  const iv = combined.slice(0, IV_LENGTH);
  const ciphertext = combined.slice(IV_LENGTH);

  const decrypted = await crypto.subtle.decrypt(
    { name: ALGORITHM, iv },
    key,
    ciphertext,
  );

  return new TextDecoder().decode(decrypted);
}

export async function encryptObject(
  obj: Record<string, string | null | undefined>,
  fields: string[],
): Promise<Record<string, string | null | undefined>> {
  const result = { ...obj };
  for (const field of fields) {
    if (result[field]) {
      result[field] = await encrypt(result[field] as string);
    }
  }
  return result;
}

export async function decryptObject(
  obj: Record<string, string | null | undefined>,
  fields: string[],
): Promise<Record<string, string | null | undefined>> {
  const result = { ...obj };
  for (const field of fields) {
    if (result[field]) {
      try {
        result[field] = await decrypt(result[field] as string);
      } catch {
        // Field may not be encrypted in older records
      }
    }
  }
  return result;
}

function hexToBytes(hex: string): Uint8Array<ArrayBuffer> {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.slice(i, i + 2), 16);
  }
  return bytes;
}