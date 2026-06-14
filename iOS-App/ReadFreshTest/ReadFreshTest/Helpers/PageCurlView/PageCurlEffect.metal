//
//  PageCurlEffect.metal
//  PageCurlView
//
//  Created by 褚宣德 on 2026/6/14.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

/// Helper Methods!
// Scale around a center point
float3x3 scaleAroundCenter(float2 scale, float2 center) {
    // Move to origin
    float3x3 moveToOrigin = float3x3(
                                     float3 (1, 0, 0),
                                     float3 (0, 1, 0),
                                     float3(-center.x, -center.y, 1)
                                     );
    // Scale
    float3x3 scaleIt = float3x3(
                                float3(scale.x, 0, 0),
                                float3(0, scale.y, 0),
                                float3(0, 0, 1)
                                );
    // Move back
    float3x3 moveBack = float3x3(
                                 float3 (1, 0, 0),
                                 float3 (0, 1, 0),
                                 float3(center.x, center.y, 1)
                                 );
    return moveBack * scaleIt * moveToOrigin;
}

// Transform a 2D point
float2 transform(float2 point, float3x3 matrix) {
    float3 p = float3(point, 1.0);
    float3 result = matrix * p;
    return result. xy;
}

// Check if point is inside rounded rectangle
bool isInside(float2 point, float4 rect, float4 corners) {
    // checking if the point in rectangle!
        bool inRect = point.x > rect.x && point.x < rect.z &&
        point.y > rect.y && point.y < rect.w;
    if (!inRect) return false;
    
    // Checking all the four corners!
    
    // Top Left
    float topLeft = corners.x;
    if (point.x < rect.x + topLeft && point.y < rect.y + topLeft) {
    float2 cornerCenter = float2(rect.x + topLeft, rect.y + topLeft);
    return length(point - cornerCenter) < topLeft;
    }
    // Top Right
    float topRight = corners.y;
    if (point.x > rect.z - topRight && point.y < rect.y + topRight) {
    float2 cornerCenter = float2(rect.z - topRight, rect.y + topRight);
    return length(point - cornerCenter) < topRight;
    }
    // Bottom Left
    float bottomLeft = corners.z;
    if (point.x < rect.x + bottomLeft && point.y > rect.w - bottomLeft) {
    float2 cornerCenter = float2(rect.x + bottomLeft, rect.w - bottomLeft);
    return length(point - cornerCenter) < bottomLeft;
    }
    // Bottom Right
    float bottomRight = corners.w;
    if (point.x > rect.z - bottomRight && point.y > rect.w - bottomRight) {
        float2 cornerCenter = float2(rect.z - bottomRight, rect.w - bottomRight);
        return length (point - cornerCenter) < bottomRight;
    }
    
    return true;
}


[[stitchable]] half4 pageCurlEffect(
                                    float2 pos,
                                    SwiftUI::Layer layer,
                                    float drag,
                                    float2 size,
                                    float4 corners,
                                    float2 center,
                                    float radius,
                                    float curlShadow,
                                    float underneathShadow
) {

    const float PI = 3.14;
    float curlX = size.x - drag;
    float dist = pos.x - curlX;
    float4 bounds = float4(0, 0, size.x, size.y);
    
    half4 color = half4(0.0);
    
    // The space after the page has curled away
    if (dist > radius) {
        color = half4(0, 0, 0, 0);
        if (isInside(pos, bounds, corners)) {
            // Applying shadow
            float fade = (dist - radius) / radius;
            color.a = mix(underneathShadow, 0.0, fade);
        }
    }
    // In the curl region
    else if (dist > 0.0) {
        // Angle around the cylinder
        float angle = asin(dist / radius);
        
        // Arc lengths
        float arcFront = angle * radius;
        float arcBack = (PI - angle) * radius;
        
        // Front of Curl
        float2 scaleFront = float2(1.0 + (1.0 - sin(PI/2.0 + angle)) * 0.1);
        float3x3 matrixFront = scaleAroundCenter (scaleFront, center);
        float2 posFront = transform(pos, matrixFront);
        float2 sampleFront = float2(curlX + arcFront, posFront.y);
        
        // Back of Curl
        float2 scaleBack = float2(1.1 + sin(PI/2.0 + angle) * 0.1);
        float3x3 matrixBack = scaleAroundCenter (scaleBack, center);
        float2 posBack = transform(pos, matrixBack);
        float2 sampleBack = float2(curlX + arcBack, posBack.y);
        
        
        if (isInside(sampleBack, bounds, corners)) {
            // Back Face
            color = half4(layer. sample(sampleBack));
            
            // White-Wash Effect for Back Face
            half3 white = half3(1.0, 1.0, 1.0);
            float fadeAmount = 0.7;
            color.rgb = mix(color.rgb, white, fadeAmount);
        } else if (isInside(sampleFront, bounds, corners)) {
            // Front Face
            color = half4(layer.sample(sampleFront));
            
            // Applying Shadow
            float shadow = pow(clamp((radius - dist) / radius, 0.0, 1.0), 1.0);
            float darken = 1.0 - (curlShadow * (1.0 - shadow));
            color.rgb *= darken;
        } else {
            // Applying Shadow Behind the Curl
            color = half4(0, 0, 0, underneathShadow);
        }
    }
    // Normal & Curled Away Region
    else {
        float2 scaleRevealed = float2(1.2);
        float3x3 matrixRevealed = scaleAroundCenter(scaleRevealed, center);
        float2 posRevealed = transform(pos, matrixRevealed);
        float2 sampleRevealed = float2(curlX + abs(dist) + PI * radius, posRevealed.y);
        
        // Curled Away Region
        if (isInside (sampleRevealed, bounds, corners)) {
            color = half4(layer. sample(sampleRevealed));
            
            // White-Wash Effect for Back Face
            half3 white = half3(1.0, 1.0, 1.0);
            float fadeAmount = 0.7;
            color.rgb = mix(color.rgb, white, fadeAmount);
        } else {
            /// Normal Region (Before any curl!)
            color = half4(layer. sample(pos));
        }
        
    }
    return color;
}
