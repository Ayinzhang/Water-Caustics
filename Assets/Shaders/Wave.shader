Shader "Wave"
{
    Properties
    {
        _Strength("Drop Strength", Float) = 0.01
    }

    HLSLINCLUDE
    #include "UnityCustomRenderTexture.cginc"
    static const float PI = 3.14159265f;

    float _Strength;

    float4 frag_integrate(v2f_customrendertexture IN) : COLOR
    {
        float2 delta = float2(1 / _CustomRenderTextureWidth, 1 / _CustomRenderTextureHeight);
        float2 coord = IN.globalTexcoord.xy;
        float4 info = tex2D(_SelfTexture2D, coord);

        float2 dx = ddx(coord);
        float2 dy = ddy(coord);
        float average = (
            tex2D(_SelfTexture2D, coord - dx).r +
            tex2D(_SelfTexture2D, coord - dy).r +
            tex2D(_SelfTexture2D, coord + dx).r +
            tex2D(_SelfTexture2D, coord + dy).r
        ) * 0.25;

        info.g += (average - info.r) * 2.0;
        info.g *= 0.99;
        info.r += info.g;

        float4 col = info;
        return col;
    }

    float4 frag_normal(v2f_customrendertexture IN) : COLOR
    {
        float4 coord = float4(IN.localTexcoord.xy, 0, 0);

        float4 info = tex2D(_SelfTexture2D, coord);
        float2 delta = float2(1 / _CustomRenderTextureWidth, 1 / _CustomRenderTextureHeight);

        float3 dx = float3(delta.x, tex2D(_SelfTexture2D, float2(coord.x + delta.x, coord.y)).r - info.r, 0.0);
        float3 dy = float3(0.0, tex2D(_SelfTexture2D, float2(coord.x, coord.y + delta.y)).r - info.r, delta.y);
        info.ba = normalize(cross(dy, dx)).xz;

        return info;
    }

    float4 frag_drop(v2f_customrendertexture IN) : COLOR
    {
        float2 coord = IN.localTexcoord.xy;
        float4 info = tex2D(_SelfTexture2D, IN.globalTexcoord.xy);
        float drop = max(0, 1.0 - length(float2(0.5, 0.5) - coord) / 0.5);
        drop = 0.5 - cos(drop * PI) * 0.5;
        info.r += (drop - 0.25 * (PI / 2 - 2 / PI)) * _Strength;
        return info;
    }
    ENDHLSL

    SubShader
    {
        Lighting Off
        Blend One Zero

        Pass
        {
            Name "Integrate"
            HLSLPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag_integrate
            ENDHLSL
        }

        Pass
        {
            Name "Drop"
            HLSLPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag_drop
            ENDHLSL
        }

        Pass
        {
            Name "Normal"
            HLSLPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag_normal
            ENDHLSL
        }
    }
}
