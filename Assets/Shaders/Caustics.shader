Shader "Caustics"
{
    Properties
    {
        _BaseMap ("Base", 2D) = "white" {}
        _WaveMap ("Wave", 2D) = "black" {}
        [HideInInspector] sphereCenter ("Sphere Center", Vector) = (0, 0, 0, 0)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 100
        Cull Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "WaterCaustics.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 oldPos : TEXCOORD1;
                float3 newPos : TEXCOORD2;
            };

            float3 Project(float3 origin, float3 ray, float3 refractedLight) 
            {
                float2 tsphere = IntersectCube(origin, ray, float3(-1.0, -1.0, -1.0), float3(1.0, 2.0, 1.0));
                origin += ray * tsphere.y;
                float tplane = (-origin.y - 1.0) / refractedLight.y;
                return origin + refractedLight * tplane;
            }

            v2f vert (appdata v)
            {
                v2f o;
                float4 info = SAMPLE_TEXTURE2D_LOD(_WaveMap, sampler_WaveMap, float4(v.vertex.xy * 0.5 + 0.5, 0, 0), 100);
                info.ba *= 0.5; 
                float3 normal = float3(info.b, sqrt(1.0 - dot(info.ba, info.ba)), info.a);
                
                float3 refractedLight = refract(-GetMainLight().direction, float3(0.0, 1.0, 0.0), IOR_AIR / IOR_WATER);
                float3 ray = refract(-GetMainLight().direction, normal, IOR_AIR / IOR_WATER);
                o.oldPos = Project(v.vertex.xzy, refractedLight, refractedLight);
                o.newPos = Project(v.vertex.xzy + float3(0.0, info.r, 0.0), ray, refractedLight);
                o.vertex = float4(0.75 * (o.newPos.xz + refractedLight.xz / refractedLight.y), 0.0, 1.0);
                o.vertex.y *= -1;

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float oldArea = length(ddx(i.oldPos)) * length(ddy(i.oldPos));
                float newArea = length(ddx(i.newPos)) * length(ddy(i.newPos));
                float4 col = float4(oldArea / newArea * 0.2, 1.0, 0.0, 0.0);
                float3 refractedLight = refract(-GetMainLight().direction, float3(0.0, 1.0, 0.0), IOR_AIR / IOR_WATER);

                float3 dir = (sphereCenter - i.oldPos) / 0.25;
                float3 area = cross(dir, refractedLight);
                float shadow = dot(area, area);
                float dist = dot(dir, -refractedLight);
                shadow = 1.0 + (shadow - 1.0) / (0.05 + dist * 0.025);
                shadow = clamp(1.0 / (1.0 + exp(-shadow)), 0.0, 1.0);
                shadow = lerp(1.0, shadow, clamp(dist * 2.0, 0.0, 1.0));
                col.g = shadow;

                float2 t = IntersectCube(i.newPos, -refractedLight, float3(-1.0, -1.0, -1.0), float3(1.0, 2.0, 1.0));
                col.r *= 1.0 / (1.0 + exp(-200.0 / (1.0 + 10.0 * (t.y - t.x)) * (i.newPos.y - refractedLight.y * t.y - 2.0 / 12.0)));

                return col;
            }
            ENDHLSL
        }
    }
}
