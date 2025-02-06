Shader "Water"
{
    Properties
    {
        _BaseMap("Base", 2D) = "white" {}
        [Normal] _BumpMap ("Bump", 2D) = "bump" {}
        _WaveMap("Wave", 2D) = "black" {}
        _SkyMap("SkyMap", Cube) = "white" {}
        [Toggle(UNDER_WATER)] _UnderWater("IsUnderWater", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull", Float) = 2
        [HideInInspector] sphereCenter ("Sphere Center", Vector) = (0, 0, 0, 0)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        Cull [_Cull] 
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature UNDER_WATER
            #include "WaterCaustics.hlsl"

            TEXTURECUBE(_SkyMap);
            SAMPLER(sampler_SkyMap);
            float _UnderWater, _Cull;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 position : TEXCOORD0;
                float3 tbn0 : TEXCOORD1;
                float3 tbn1 : TEXCOORD2;
                float3 tbn2 : TEXCOORD3;
            };

            float3 GetSurfaceRayColor(float3 origin, float3 ray, float3 waterColor, float3 tbn0, float3 tbn1, float3 tbn2) 
            {
                float3 color;
                float q = IntersectSphere(origin, ray, sphereCenter);
                if (q < 1e6) color = GetSphereColor(origin + ray * q);
                else if (ray.y < 0.0) 
                {
                    float2 t = IntersectCube(origin, ray, float3(-1.0, -1.0, -1.0), float3(1.0, 2.0, 1.0));
                    float3 tNormal = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, (origin + ray * t.y).xz * 0.5 + 0.5));
                    float3 normal = normalize(tbn0 * tNormal.x + tbn1 * tNormal.y + tbn2 * tNormal.z);
                    color = GetWallColor(origin + ray * t.y, normal);
                } 
                else 
                {
                    float2 t = IntersectCube(origin, ray, float3(-1.0, -1.0, -1.0), float3(1.0, 2.0, 1.0));
                    float3 hit = origin + ray * t.y;
                    if (hit.y < 1.0 / 6) 
                    {
                        float3 tNormal = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, hit.xz * 0.5 + 0.5));
                        float3 normal = normalize(tbn0 * tNormal.x + tbn1 * tNormal.y + tbn2 * tNormal.z);
                        color = GetWallColor(hit, normal);
                    }
                    else 
                    {
                        color = SAMPLE_TEXTURECUBE(_SkyMap, sampler_SkyMap, ray).rgb;
                        color += pow(max(0.0, dot(GetMainLight().direction, ray)), 5000.0) * float3(10.0, 8.0, 6.0);
                    }
                }
                if (ray.y < 0.0) color *= waterColor;
                return color;
            }


            v2f vert (appdata v)
            {
                v2f o;
                float4 info = SAMPLE_TEXTURE2D_LOD(_WaveMap, sampler_WaveMap, float4(v.vertex.xy * 0.5 + 0.5, 0, 0), 100);
                o.position = v.vertex.xzy;
                o.position.y += info.r;
                o.vertex = TransformObjectToHClip(o.position);
                float3 normal = TransformObjectToWorldNormal(v.normal);
                float3 tangent = TransformObjectToWorldDir(v.tangent.xyz);
                float3 bitangent = normalize(cross(normal, tangent));
                o.tbn0 = float3(tangent.x, bitangent.x, normal.x);
                o.tbn1 = float3(tangent.y, bitangent.y, normal.y);
                o.tbn2 = float3(tangent.z, bitangent.z, normal.z);
                return o;
            }


            float4 frag (v2f i) : SV_Target
            {
                float2 coord = i.position.xz * 0.5 + 0.5;
                float4 info = SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, coord);

                for (int j = 0; j < 5; j++) 
                {
                    coord += info.ba * 0.005;
                    info = SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, coord);
                }

                float3 normal = float3(info.b, sqrt(1.0 - dot(info.ba, info.ba)), info.a);
                float3 incomingRay = normalize(i.position - GetCameraPositionWS());

                #if UNDER_WATER
                normal = -normal;
                float3 reflectedRay = reflect(incomingRay, normal);
                float3 refractedRay = refract(incomingRay, normal, IOR_WATER / IOR_AIR);
                float fresnel = lerp(0.5, 1.0, pow(1.0 - dot(normal, -incomingRay), 3.0));
                float3 reflectedColor = GetSurfaceRayColor(i.position, reflectedRay, UNDER_WATER_COLOR, i.tbn0, i.tbn1, i.tbn2);
                float3 refractedColor = GetSurfaceRayColor(i.position, refractedRay, float3(1, 1, 1), i.tbn0, i.tbn1, i.tbn2) * float3(0.8, 1.0, 1.1);
                float4 col = float4(lerp(reflectedColor, saturate(refractedColor), (1.0 - fresnel) * length(refractedRay)), 1.0);
                
                #else
                /* above _WaveMap */
                float3 reflectedRay = reflect(incomingRay, normal);
                float3 refractedRay = refract(incomingRay, normal, IOR_AIR / IOR_WATER);
                float fresnel = lerp(0.25, 1.0, pow(1.0 - dot(normal, -incomingRay), 3.0));
                float3 reflectedColor = GetSurfaceRayColor(i.position, reflectedRay, ABOVE_WATER_COLOR, i.tbn0, i.tbn1, i.tbn2);
                float3 refractedColor = GetSurfaceRayColor(i.position, refractedRay, ABOVE_WATER_COLOR, i.tbn0, i.tbn1, i.tbn2);
                float4 col = float4(lerp(refractedColor, reflectedColor, fresnel), 1.0);
                #endif

                return col;
            }
            ENDHLSL
        }
    }
}
