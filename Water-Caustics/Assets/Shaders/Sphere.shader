Shader "Sphere"
{
    Properties
    {
        _WaveMap ("Wave", 2D) = "black" {}
        _CausticMap ("Caustics", 2D) = "white" {}
        [HideInInspector] sphereCenter ("Sphere Center", Vector) = (0, 0, 0, 0)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
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
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 position : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.position = sphereCenter + v.vertex.xyz * 0.25;
                o.vertex = TransformObjectToHClip(o.position);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = float4(GetSphereColor(i.position), 1.0);
                float4 info = SAMPLE_TEXTURE2D(_WaveMap, sampler_WaveMap, i.position.xz * 0.5 + 0.5);
                if (i.position.y < info.r) col.rgb *= UNDER_WATER_COLOR * 1.2;
                return col;
            }
            ENDHLSL
        }
    }
}
