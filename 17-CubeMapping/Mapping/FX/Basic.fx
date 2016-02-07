// ================================================= //
// Basic.fx
// ================================================= //

#include "LightHelper.fx"

// ================================================= //

cbuffer cbPerFrame {
    DirectionalLight gDirLights[3];
    float3 gEyePosW;

    float gFogStart;
    float gFogRange;
    float4 gFogColor;
};

cbuffer cbPerObject {
    float4x4 gWorld;
    float4x4 gWorldInvTranspose;
    float4x4 gWorldViewProj;
    float4x4 gTexTransform;
    Material gMaterial;
};

// ================================================= //

// Non-numeric values cannot be added to a cbuffer.
Texture2D gDiffuseMap;
TextureCube gCubeMap;

// ================================================= //

SamplerState samAnisotropic {
    Filter = ANISOTROPIC;
    MaxAnisotropy = 4;

    AddressU = WRAP;
    AddressV = WRAP;
};

// ================================================= //

struct VertexIn {
    float3 PosL : POSITION;
    float3 NormalL : NORMAL;
    float2 Tex : TEXCOORD;
};

struct VertexOut {
    float4 PosH : SV_POSITION;
    float3 PosW : POSITION;
    float3 NormalW : NORMAL;
    float2 Tex : TEXCOORD;
};

// ================================================= //

// Vertex Shader.
VertexOut VS( VertexIn vin )
{
    VertexOut vout;

    // Transform to world space.
    vout.PosW = mul( float4( vin.PosL, 1.f ), gWorld ).xyz;
    vout.NormalW = mul( vin.NormalL, ( float3x3 )gWorldInvTranspose );

    // Transform to homogeneous clip space.
    vout.PosH = mul( float4( vin.PosL, 1.f ), gWorldViewProj );

    // Output vertex attributes for interpolation across triangle.
    vout.Tex = mul( float4( vin.Tex, 0.f, 1.f ), gTexTransform ).xy;

    return vout;
}

// ================================================= //

// Pixel Shader.
float4 PS( VertexOut pin,
           uniform int gLightCount,
           uniform bool gUseTexture,
           uniform bool gAlphaClip,
           uniform bool gFogEnabled,
           uniform bool gReflectionEnabled ) : SV_TARGET
{
    // Normalize normal again in case interpolation unnormalized it during rasterization.
    pin.NormalW = normalize( pin.NormalW );

    // The vector from surface point to the eye.
    float3 toEye = gEyePosW - pin.PosW;

    // Cache distance to eye from this surface point.
    const float distToEye = length( toEye );

    // Normalize.
    toEye /= distToEye;

    //
    // Texturing

    // Default to multiplicative identity.
    float4 texColor = float4( 1, 1, 1, 1 );
    if ( gUseTexture ) {
        // Sample texture.
        texColor = gDiffuseMap.Sample( samAnisotropic, pin.Tex );

        if ( gAlphaClip ) {
            clip( texColor.a - 0.1f );
        }
    }

    //
    // Lighting
    float4 pixel = texColor;
    if ( gLightCount > 0 ) {
        // Begin with zero.
        float4 ambient = float4( 0.0f, 0.0f, 0.0f, 0.0f );
        float4 diffuse = float4( 0.0f, 0.0f, 0.0f, 0.0f );
        float4 spec = float4( 0.0f, 0.0f, 0.0f, 0.0f );

        // Sum the light contribution from each light source.
        [unroll]
        for ( int i = 0; i < gLightCount; ++i ) {
            float4 A, D, S;
            ComputeDirectionalLight( gMaterial,
                                     gDirLights[i],
                                     pin.NormalW,
                                     toEye,
                                     A,
                                     D,
                                     S );
            ambient += A;
            diffuse += D;
            spec += S;
        }

        // Modulate with late add.
        pixel = texColor * ( ambient + diffuse ) + spec;

        if ( gReflectionEnabled ) {
            float3 incident = -toEye;
            float3 reflectionVector = reflect( incident, pin.NormalW );
            float4 reflectionColor = gCubeMap.Sample( samAnisotropic, reflectionVector );

            pixel += gMaterial.reflect * reflectionColor;
        }
    }    

    // Common to take alpha from diffuse material and texture.
    pixel.a = gMaterial.diffuse.a * texColor.a;

    return pixel;
}

// ================================================= //

technique11 Light1 {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, false, false, false, false ) ) );
    }
}

technique11 Light2 {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, false, false, false, false ) ) );
    }
}

technique11 Light3 {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, false, false, false, false ) ) );
    }
}

technique11 Light0Tex {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 0, true, false, false, false ) ) );
    }
}

technique11 Light1Tex {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, true, false, false, false ) ) );
    }
}

technique11 Light2Tex {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, true, false, false, false ) ) );
    }
}

technique11 Light3Tex {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, true, false, false, false ) ) );
    }
}

technique11 Light0TexAlphaClip {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 0, true, true, false, false ) ) );
    }
}

technique11 Light1TexAlphaClip {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, true, true, false, false ) ) );
    }
}

technique11 Light2TexAlphaClip {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, true, true, false, false ) ) );
    }
}

technique11 Light3TexAlphaClip {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, true, true, false, false ) ) );
    }
}

technique11 Light1Fog {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, false, false, true, false ) ) );
    }
}

technique11 Light2Fog {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, false, false, true, false ) ) );
    }
}

technique11 Light3Fog {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, false, false, true, false ) ) );
    }
}

technique11 Light0TexFog {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 0, true, false, true, false ) ) );
    }
}

technique11 Light1TexFog {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, true, false, true, false ) ) );
    }
}

technique11 Light2TexFog {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, true, false, true, false ) ) );
    }
}

technique11 Light3TexFog {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, true, false, true, false ) ) );
    }
}

technique11 Light0TexAlphaClipFog {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 0, true, true, true, false ) ) );
    }
}

technique11 Light1TexAlphaClipFog {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, true, true, true, false ) ) );
    }
}

technique11 Light2TexAlphaClipFog {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, true, true, true, false ) ) );
    }
}

technique11 Light3TexAlphaClipFog {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, true, true, true, false ) ) );
    }
}

technique11 Light1Reflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, false, false, false, true ) ) );
    }
}

technique11 Light2Reflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, false, false, false, true ) ) );
    }
}

technique11 Light3Reflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, false, false, false, true ) ) );
    }
}

technique11 Light0TexReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 0, true, false, false, true ) ) );
    }
}

technique11 Light1TexReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, true, false, false, true ) ) );
    }
}

technique11 Light2TexReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, true, false, false, true ) ) );
    }
}

technique11 Light3TexReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, true, false, false, true ) ) );
    }
}

technique11 Light0TexAlphaClipReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 0, true, true, false, true ) ) );
    }
}

technique11 Light1TexAlphaClipReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, true, true, false, true ) ) );
    }
}

technique11 Light2TexAlphaClipReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, true, true, false, true ) ) );
    }
}

technique11 Light3TexAlphaClipReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, true, true, false, true ) ) );
    }
}

technique11 Light1FogReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, false, false, true, true ) ) );
    }
}

technique11 Light2FogReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, false, false, true, true ) ) );
    }
}

technique11 Light3FogReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, false, false, true, true ) ) );
    }
}

technique11 Light0TexFogReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 0, true, false, true, true ) ) );
    }
}

technique11 Light1TexFogReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, true, false, true, true ) ) );
    }
}

technique11 Light2TexFogReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, true, false, true, true ) ) );
    }
}

technique11 Light3TexFogReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, true, false, true, true ) ) );
    }
}

technique11 Light0TexAlphaClipFogReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 0, true, true, true, true ) ) );
    }
}

technique11 Light1TexAlphaClipFogReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 1, true, true, true, true ) ) );
    }
}

technique11 Light2TexAlphaClipFogReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 2, true, true, true, true ) ) );
    }
}

technique11 Light3TexAlphaClipFogReflect {
    pass P0 {
        SetVertexShader( CompileShader( vs_5_0, VS() ) );
        SetGeometryShader( NULL );
        SetPixelShader( CompileShader( ps_5_0, PS( 3, true, true, true, true ) ) );
    }
}

// ================================================= //