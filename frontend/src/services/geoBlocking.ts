/**
 * Geo-blocking service for US users
 * Uses free IP geolocation API to detect user location
 */

export interface GeoLocation {
  country: string;
  countryCode: string;
  region: string;
  city: string;
  ip: string;
}

export interface GeoBlockResult {
  isBlocked: boolean;
  reason?: string;
  location?: GeoLocation;
}

// List of blocked country codes
const BLOCKED_COUNTRIES = ["US", "USA"];

// Cache duration in milliseconds (1 hour)
const CACHE_DURATION = 60 * 60 * 1000;

// Storage key for cached location
const CACHE_KEY = "paimon_geo_location";

interface CachedLocation {
  location: GeoLocation;
  timestamp: number;
}

/**
 * Get cached location from localStorage
 */
function getCachedLocation(): GeoLocation | null {
  if (typeof window === "undefined") return null;

  try {
    const cached = localStorage.getItem(CACHE_KEY);
    if (!cached) return null;

    const parsed: CachedLocation = JSON.parse(cached);
    const now = Date.now();

    // Check if cache is still valid
    if (now - parsed.timestamp < CACHE_DURATION) {
      return parsed.location;
    }

    // Cache expired, remove it
    localStorage.removeItem(CACHE_KEY);
    return null;
  } catch {
    return null;
  }
}

/**
 * Cache location in localStorage
 */
function cacheLocation(location: GeoLocation): void {
  if (typeof window === "undefined") return;

  try {
    const cached: CachedLocation = {
      location,
      timestamp: Date.now(),
    };
    localStorage.setItem(CACHE_KEY, JSON.stringify(cached));
  } catch {
    // Ignore storage errors
  }
}

/**
 * Fetch user's geo location from IP
 * Uses ip-api.com (free, no API key required, 45 requests/minute limit)
 */
export async function getGeoLocation(): Promise<GeoLocation | null> {
  // Check cache first
  const cached = getCachedLocation();
  if (cached) return cached;

  try {
    // Primary API: ip-api.com (free, no key required)
    const response = await fetch("http://ip-api.com/json/?fields=status,country,countryCode,region,city,query");

    if (!response.ok) {
      throw new Error("Failed to fetch geo location");
    }

    const data = await response.json();

    if (data.status !== "success") {
      throw new Error("Geo location API returned error");
    }

    const location: GeoLocation = {
      country: data.country,
      countryCode: data.countryCode,
      region: data.region || "",
      city: data.city || "",
      ip: data.query,
    };

    // Cache the result
    cacheLocation(location);

    return location;
  } catch (error) {
    console.error("Geo location fetch failed:", error);

    // Fallback API: ipapi.co (free tier: 1000 requests/day)
    try {
      const fallbackResponse = await fetch("https://ipapi.co/json/");

      if (!fallbackResponse.ok) {
        throw new Error("Fallback geo location failed");
      }

      const fallbackData = await fallbackResponse.json();

      const location: GeoLocation = {
        country: fallbackData.country_name,
        countryCode: fallbackData.country_code,
        region: fallbackData.region || "",
        city: fallbackData.city || "",
        ip: fallbackData.ip,
      };

      cacheLocation(location);
      return location;
    } catch (fallbackError) {
      console.error("Fallback geo location also failed:", fallbackError);
      return null;
    }
  }
}

/**
 * Check if user should be blocked based on their location
 */
export async function checkGeoBlocking(): Promise<GeoBlockResult> {
  const location = await getGeoLocation();

  // If we can't determine location, allow access (fail-open for UX)
  // In production, you might want to fail-closed for stricter compliance
  if (!location) {
    console.warn("Could not determine user location, allowing access");
    return {
      isBlocked: false,
      reason: "Location could not be determined",
    };
  }

  const isBlocked = BLOCKED_COUNTRIES.includes(location.countryCode);

  if (isBlocked) {
    // Log blocked access attempt (in production, send to analytics/logging service)
    console.log("Blocked access attempt from:", {
      country: location.country,
      countryCode: location.countryCode,
      timestamp: new Date().toISOString(),
    });
  }

  return {
    isBlocked,
    reason: isBlocked
      ? `Access is not available in ${location.country} due to regulatory restrictions`
      : undefined,
    location,
  };
}

/**
 * Clear geo location cache (useful for testing)
 */
export function clearGeoCache(): void {
  if (typeof window === "undefined") return;
  localStorage.removeItem(CACHE_KEY);
}
