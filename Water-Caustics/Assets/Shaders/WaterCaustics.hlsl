#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

static const float IOR_AIR = 1.0, IOR_WATER = 1.333;
static const float3 ABOVE_WATER_COLOR = float3(0.25, 1.0, 1.25), UNDER_WATER_COLOR = float3(0.4, 0.9, 1.0);
float3 sphereCenter;
TEXTURE2D(_BaseMap); TEXTURE2D(_BumpMap); TEXTURE2D(_CausticMap); TEXTURE2D(_WaveMap);
SAMPLER(sampler_BaseMap); SAMPLER(sampler_BumpMap); SAMPLER(sampler_CausticMap); SAMPLER(sampler_WaveMap);

float2 IntersectCube(float3 origin, float3 ray, float3 sphereMin, float3 sphereMax)
{
    float3 tMin = (sphereMin - origin) / ray;
    float3 tMax = (sphereMax - origin) / ray;
    float3 t1 = min(tMin, tMax);
    float3 t2 = max(tMin, tMax);
    float tNear = max(max(t1.x, t1.y), t1.z);
    float tFar = min(min(t2.x, t2.y), t2.z);
    return float2(tNear, tFar);
}

float IntersectSphere(float3 origin, float3 ray, float3 sphereCenter) 
{
    float3 toSphere = origin - sphereCenter;
    float a = dot(ray, ray), b = 2.0 * dot(toSphere, ray);
    float c = dot(toSphere, toSphere) - 0.0625, discriminant = b * b - 4.0 * a * c;
    if (discriminant > 0.0) 
    {
        float t = (-b - sqrt(discriminant)) / (2.0 * a);
        if (t > 0) return t;
    }
    return 1e6;
}

float3 GetSphereColor(float3 _point) 
{
    float3 color = float3(0.5, 0.5, 0.5);

    /* ambient occlusion with walls */
    color *= 1.0 - 0.9 / pow((1.0 + 0.25 - abs(_point.x)) / 0.25, 3.0);
    color *= 1.0 - 0.9 / pow((1.0 + 0.25 - abs(_point.z)) / 0.25, 3.0);
    color *= 1.0 - 0.9 / pow((_point.y + 1.0 + 0.25) / 0.25, 3.0);

    /* caustics */
    float3 sphereNormal = (_point - sphereCenter) / 0.25;
    float3 refractedLight = refract(-GetMainLight().direction, float3(0.0, 1.0, 0.0), IOR_AIR / IOR_WATER);
    float diffuse = max(0.0, dot(-refractedLight, sphereNormal)) * 0.5;
    float4 info = SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, _point.xz * 0.5 + 0.5);
    if (_point.y < info.r) 
    {
        float4 caustic = SAMPLE_TEXTURE2D(_CausticMap, sampler_CausticMap, 0.75 * (_point.xz - _point.y * refractedLight.xz / refractedLight.y) * 0.5 + 0.5);
        diffuse *= caustic.r * 4.0;
    }
    color += diffuse;

    return color;
}

float3 GetWallColor(float3 _point) 
{
    float scale = 0.5; float3 wallColor, normal;

    if (abs(_point.x) > 0.999) 
    {
        wallColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, _point.yz * 0.5 + float2(1.0, 0.5)).rgb;
        normal = float3(-_point.x, 0.0, 0.0);
    }
    else if (abs(_point.z) > 0.999) 
    {
        wallColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, _point.yx * 0.5 + float2(1.0, 0.5)).rgb;
        normal = float3(0.0, 0.0, -_point.z);
    }
    else 
    {
        wallColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, _point.xz * 0.5 + 0.5).rgb;
        normal = float3(0.0, 1.0, 0.0);
    }

    scale /= length(_point);
    scale *= 1.0 - 0.9 / pow(length(_point - sphereCenter) / 0.25, 4.0); 
    float3 refractedLight = -refract(-GetMainLight().direction, float3(0.0, 1.0, 0.0), IOR_AIR / IOR_WATER);
    float diffuse = max(0.0, dot(refractedLight, normal));
    float4 info = SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, _point.xz * 0.5 + 0.5);
    if (_point.y < info.r) 
    {
        float4 caustic = SAMPLE_TEXTURE2D(_CausticMap, sampler_CausticMap, 0.75 * (_point.xz - _point.y * refractedLight.xz / refractedLight.y) * 0.5 + 0.5);
        scale += diffuse * caustic.r * 2.0 * caustic.g;
    }
    else 
    {
        float2 t = IntersectCube(_point, refractedLight, float3(-1.0, -1.0, -1.0), float3(1.0, 2.0, 1.0));
        diffuse *= 1.0 / (1.0 + exp(-200.0 / (1.0 + 10.0 * (t.y - t.x)) * (_point.y + refractedLight.y * t.y - 2.0 / 12.0)));
        scale += diffuse * 0.5;
    }

    return wallColor * scale;
}

float3 GetWallColor(float3 _point, float3 normal)
{
    float scale = 0.5; float3 wallColor;

    if (abs(_point.x) > 0.999) wallColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, _point.yz * 0.5 + float2(1.0, 0.5)).rgb;
    else if (abs(_point.z) > 0.999) wallColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, _point.yx * 0.5 + float2(1.0, 0.5)).rgb;
    else wallColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, _point.xz * 0.5 + 0.5).rgb;

    scale /= length(_point); 
    scale *= 1.0 - 0.9 / pow(length(_point - sphereCenter) / 0.25, 4.0);

    float3 refractedLight = -refract(-GetMainLight().direction, float3(0.0, 1.0, 0.0), IOR_AIR / IOR_WATER);
    float diffuse = max(0.0, dot(refractedLight, normal));

    float4 info = SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, _point.xz * 0.5 + 0.5);
    if (_point.y < info.r)
    {
        float4 caustic = SAMPLE_TEXTURE2D(_CausticMap, sampler_CausticMap, 0.75 * (_point.xz - _point.y * refractedLight.xz / refractedLight.y) * 0.5 + 0.5);
        scale += diffuse * caustic.r * 2.0 * caustic.g;
    }
    else
    {
        float2 t = IntersectCube(_point, refractedLight, float3(-1.0, -1.0, -1.0), float3(1.0, 2.0, 1.0));
        diffuse *= 1.0 / (1.0 + exp(-200.0 / (1.0 + 10.0 * (t.y - t.x)) * (_point.y + refractedLight.y * t.y - 2.0 / 12.0)));
        scale = max(0.5, scale + 0.5 * diffuse);
    }

    return wallColor * scale;
}
