Shader "Cube"
{
    Properties
    {
        _BaseMap ("Base", 2D) = "white" {}
        [Normal] _BumpMap ("Bump", 2D) = "bump" {}
        _WaveMap ("Wave", 2D) = "black" {}
        _CausticMap ("Caustics", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        Cull Front
        LOD 100 

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "WaterCaustics.hlsl"
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

            v2f vert (appdata v)
            {
                v2f o;
                o.position = v.vertex.xyz;
                o.position.y = (1.0 - o.position.y) * (7.0 / 12.0) - 1.0;
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
                float3 tNormal = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.position.xz * 0.5 + 0.5));
                float3 normal = normalize(i.tbn0 * tNormal.x + i.tbn1 * tNormal.y + i.tbn2 * tNormal.z);
                float4 col = float4(GetWallColor(i.position, normal), 1);
                float4 info = SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, i.position.xz * 0.5 + 0.5);
                if (i.position.y < info.r) col.rgb *= 1.2 * UNDER_WATER_COLOR;
                return col;
            }
            ENDHLSL
        }
    }
}
