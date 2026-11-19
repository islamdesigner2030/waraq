#include <metal_stdlib>
using namespace metal;

// Must match `CurlUniforms` in CurlGeometry.swift (80 bytes).
struct CurlUniforms {
    float2 viewSize;     // points
    float2 pageOrigin;   // top-left of the page in the view, points
    float2 pageSize;     // points
    float2 linePoint;    // a point on the curl line (logical page space)
    float2 lineNormal;   // unit vector pointing toward the lifted part
    float  radius;       // curl cylinder radius, points
    float  mirror;       // 1 = right-to-left notebook (mirror x)
    float  zScale;       // depth scale
    float  shadowStrength;
    float4 backTint;     // paper colour seen on the back of the sheet
};

struct PageOut {
    float4 position [[position]];
    float2 uv;
    float3 normal;
    float  dist;     // signed distance from the curl line before bending
    float  height;   // lift above the page plane
};

// Logical space: the free edge being turned is always on the right (x = pageSize.x),
// the spine on the left (x = 0). Right-to-left notebooks are mirrored on output.
vertex PageOut curlVertex(uint vid [[vertex_id]],
                          const device float2 *uvs [[buffer(0)]],
                          constant CurlUniforms &u [[buffer(1)]])
{
    float2 uv = uvs[vid];
    float2 p = uv * u.pageSize;
    float r = max(u.radius, 0.0001);
    float d = dot(p - u.linePoint, u.lineNormal);

    float3 pos = float3(p, 0.0);
    float3 n = float3(0.0, 0.0, 1.0);

    if (d > 0.0) {
        float2 foot = p - u.lineNormal * d;
        float halfTurn = M_PI_F * r;
        if (d < halfTurn) {
            // wrapped around the cylinder
            float th = d / r;
            pos.xy = foot + u.lineNormal * (r * sin(th));
            pos.z = r * (1.0 - cos(th));
            n = float3(-u.lineNormal * sin(th), cos(th));
        } else {
            // flat again, lying back over the page, face down
            pos.xy = foot - u.lineNormal * (d - halfTurn);
            pos.z = 2.0 * r;
            n = float3(0.0, 0.0, -1.0);
        }
    }

    bool rtl = u.mirror > 0.5;
    float x = rtl ? (u.pageSize.x - pos.x) : pos.x;
    float2 s = u.pageOrigin + float2(x, pos.y);

    PageOut o;
    o.position = float4(s.x / u.viewSize.x * 2.0 - 1.0,
                        1.0 - s.y / u.viewSize.y * 2.0,
                        clamp(0.5 - pos.z * u.zScale, 0.0, 0.9),
                        1.0);
    o.uv = float2(rtl ? 1.0 - uv.x : uv.x, uv.y);
    o.normal = float3(rtl ? -n.x : n.x, n.y, n.z);
    o.dist = d;
    o.height = pos.z;
    return o;
}

fragment float4 curlFragment(PageOut in [[stage_in]],
                             texture2d<float> tex [[texture(0)]],
                             sampler smp [[sampler(0)]],
                             constant CurlUniforms &u [[buffer(1)]])
{
    float4 c = tex.sample(smp, in.uv);       // premultiplied
    float3 n = normalize(in.normal);
    bool front = n.z >= 0.0;

    float3 light = normalize(float3(-0.35, -0.55, 1.0));
    float diffuse = abs(dot(n, light));
    float shade = mix(0.70, 1.0, diffuse);
    float3 h = normalize(light + float3(0.0, 0.0, 1.0));
    float spec = pow(saturate(abs(dot(n, h))), 28.0) * 0.10;

    float3 rgb;
    if (front) {
        rgb = c.rgb * shade;
        // the lifted flap darkens the flat page right next to the fold
        if (in.height < 0.01 && in.dist < 0.0) {
            float r = max(u.radius, 1.0);
            float ao = 1.0 - 0.20 * u.shadowStrength * exp(in.dist / (r * 0.9 + 6.0));
            rgb *= ao;
        }
    } else {
        // back of the sheet: plain paper with a faint show-through of the ink
        float3 paper = u.backTint.rgb * c.a;
        rgb = mix(paper, c.rgb, 0.09) * mix(0.80, 1.0, diffuse);
    }
    rgb += spec * c.a;
    return float4(rgb, c.a);
}

struct ShadowOut {
    float4 position [[position]];
    float2 logical;
};

// A soft shadow the curling sheet casts on the page underneath.
vertex ShadowOut shadowVertex(uint vid [[vertex_id]],
                              constant CurlUniforms &u [[buffer(1)]])
{
    const float2 corners[4] = { float2(0.0, 0.0), float2(1.0, 0.0), float2(0.0, 1.0), float2(1.0, 1.0) };
    float2 p = corners[vid] * u.pageSize;
    float x = u.mirror > 0.5 ? (u.pageSize.x - p.x) : p.x;
    float2 s = u.pageOrigin + float2(x, p.y);
    ShadowOut o;
    o.position = float4(s.x / u.viewSize.x * 2.0 - 1.0, 1.0 - s.y / u.viewSize.y * 2.0, 0.95, 1.0);
    o.logical = p;
    return o;
}

fragment float4 shadowFragment(ShadowOut in [[stage_in]],
                               constant CurlUniforms &u [[buffer(1)]])
{
    float d = dot(in.logical - u.linePoint, u.lineNormal);
    if (d <= 0.0) {
        discard_fragment();
    }
    float r = max(u.radius, 1.0);
    float x = max(d - r * 0.55, 0.0);
    float a = u.shadowStrength * 0.34 * exp(-x / (r * 1.3 + 14.0));
    return float4(0.0, 0.0, 0.0, a);
}
