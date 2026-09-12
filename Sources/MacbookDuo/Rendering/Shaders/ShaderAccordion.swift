import Foundation

/// Accordion: a paper fan of horizontal pleats zig-zags and gathers at the hinge.
enum ShaderAccordion {
    static let function = #"""
    // ---------------------------------------------------------------- Accordion
    // N equal pleats zig-zag in depth, anchored at the hinge, seen from a camera
    // elevated by phi. Even pleats lift their top edge toward the viewer and
    // foreshorten to cos(theta+phi); odd pleats turn to face the camera and keep
    // cos(theta-phi). Pairs stack in constant strides, so the pleat under a pixel
    // is one floor(): its band is stretched linearly back onto its source band,
    // valleys sit deeper so they draw in at the sides, faces shade by facing, and
    // creases draw a bright ridge or a dark seam. Everything above is folded away.
    static float4 foldAccordion(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, constant Uniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float inten = clamp(u.intensity,0.0f,1.0f);
        uint n = clamp(u.segments,2u,8u);
        float h = 1.0f-uv.y;
        float band = 1.0f/float(n);
        const float degree = M_PI_F/180.0f;

        // Tilt gathers quickly at first, then settles; the fan never passes flat.
        float thetaMax = min(40.0f+70.0f*inten,88.0f)*degree;
        float theta = thetaMax*(1.0f-(1.0f-p)*(1.0f-p));
        float sinT = sin(theta);
        float phi = (6.0f+10.0f*persp)*degree;
        float cosPhi = cos(phi);
        float away = band*max(cos(theta+phi),0.05f)/cosPhi;
        float toward = band*cos(theta-phi)/cosPhi;
        float pair = away+toward;
        float stack = float(n/2u)*pair+((n&1u) ? away : 0.0f);

        float k = floor(h/pair);
        float rem = h-k*pair;
        bool awayFace = rem < away;
        uint i = uint(k)*2u+(awayFace ? 0u : 1u);
        float span = awayFace ? away : toward;
        float local = (awayFace ? rem : rem-away)/span;
        i = min(i,n-1u);
        float sourceH = (float(i)+local)*band;
        // Ridges come forward, valleys recede: the recess narrows a valley row.
        float depth = sinT*band*(awayFace ? 1.0f-local : local);
        float scaleX = 1.0f-0.9f*persp*depth;
        float sourceX = 0.5f+(uv.x-0.5f)/scaleX;

        // Prefilter the foreshortened faces; softness defocuses by tilt.
        float minify = max(band/span-1.0f,0.0f);
        float focus = u.defocus >= 0 ? u.defocus : p;
        float sigmaUV = min(0.5f*minify/float(desktop.get_height()),0.03f)
                      + soft*0.032f*focus*sinT*(awayFace ? 1.0f : 0.55f);
        float3 color = foldSample(desktop,pyramid,s,float2(sourceX,1.0f-sourceH),sigmaUV);

        // Faces turned from the light darken; faces turned to it carry a soft
        // highlight band near their forward ridge and dim into the valley.
        float relief = shad*smoothstep(0.0f,0.10f,p);
        float shade;
        if (awayFace) {
            shade = 1.0f-relief*(0.22f+0.45f*sinT)*(1.0f-0.3f*local);
        } else {
            float highlight = exp(-pow((local-0.30f)/0.28f,2.0f));
            shade = 1.0f+relief*sinT*(0.18f*highlight-0.10f*smoothstep(0.55f,1.0f,local));
        }
        // Creases: valleys (between a toward face below and an away face above)
        // take a thin dark seam, ridges a thin bright edge. The hinge has neither.
        float onset = smoothstep(0.0f,0.10f,p);
        float width = 0.0022f+0.004f*soft;
        float dBottom = local*span, dTop = (1.0f-local)*span;
        float ridge = awayFace ? dTop : dBottom;
        float valley = awayFace ? (i == 0u ? 1e9f : dBottom) : dTop;
        float seam = 1.0f-(0.20f+0.45f*shad)*onset*exp(-valley/width);
        float edge = 1.0f+(0.10f+0.25f*shad)*onset*exp(-ridge/width);
        color *= shade*seam*edge;

        // Everything above the gathered stack has already folded away.
        float feather = 0.0022f+0.004f*soft;
        float featherX = feather*u.size.y/max(u.size.x,1.0f);
        float cover = smoothstep(0.0f,feather,stack-h)
                    * smoothstep(0.0f,featherX,sourceX)*smoothstep(0.0f,featherX,1.0f-sourceX);
        return float4(min(color,float3(1.0f))*cover*(1.0f-smoothstep(0.88f,1.0f,p)),1);
    }
    """#
}
