#version 430 core
#extension GL_NV_uniform_buffer_std430_layout: enable

in vec2 screenCoord;
out vec4 FragColor;

struct Ray { vec3 origin, direction; };
struct Camera { vec3 position, forward, right, up; };
struct Triangle { vec3 v0, v1, v2, n; };
struct FlattenedKDNode { int left, right, count, tri, tri1, tri2, tri3; vec3 aabbMin, aabbMax; };
struct FlattenedBVHNode { int left, right, count; vec3 aabbMin, aabbMax; };

uniform Camera camera;
uniform int triangleCount, bvhCount;
layout(std430, binding = 0) buffer TriangleBlock{ Triangle triangles[]; };
layout(std430, binding = 1) buffer BVHBlock{ FlattenedBVHNode bvhNodes[];};
layout(std430, binding = 2) buffer AABBIntersectionBuffer { int aabbCollisionCounts[]; };

Ray CreateRay(vec3 o, vec3 d)
{
    Ray ray;
    ray.origin = o;
    ray.direction = normalize(d);
    return ray;
}

bool RayTriangleIntersect(Ray ray, Triangle tri, out float t, out vec3 hitPoint)
{
    vec3 edge1 = tri.v1 - tri.v0, edge2 = tri.v2 - tri.v0, h = cross(ray.direction, edge2);
    float a = dot(edge1, h);

    if (abs(a) < 1e-6) return false;

    float f = 1.0 / a;
    vec3 s = ray.origin - tri.v0;
    float u = f * dot(s, h);
    if (u < 0.0 || u > 1.0) return false;

    vec3 q = cross(s, edge1);
    float v = f * dot(ray.direction, q);
    if (v < 0.0 || u + v > 1.0) return false;

    t = f * dot(edge2, q);
    if (t > 1e-6)
    {
        hitPoint = ray.origin + t * ray.direction;
        return true;
    }

    return false;
}

vec3 RayTrace(Ray ray)
{
    float closestT = 1e20, t = (ray.direction.y + 1.0) * 0.5;
    vec3 color = (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);

    for (int i = 0; i < triangleCount; i++)
    {
        float t; vec3 hitPoint;
        if (RayTriangleIntersect(ray, triangles[i], t, hitPoint))
        {
            if (t < closestT)
            {
                closestT = t;
                vec3 lightPos = vec3(10.0, 10.0, 10.0);
                vec3 lightDir = normalize(lightPos - hitPoint);
                float diff = max(dot(triangles[i].n, lightDir), 0.0);
                color = vec3(0.8) * diff;
            }
        }
    }

    return color;
}

bool RayAABBIntersect(Ray ray, vec3 aabbMin, vec3 aabbMax)
{
    vec3 invDir = 1.0 / ray.direction;
    vec3 t0s = (aabbMin - ray.origin) * invDir;
    vec3 t1s = (aabbMax - ray.origin) * invDir;
    
    vec3 tMinVec = min(t0s, t1s);
    vec3 tMaxVec = max(t0s, t1s);
    
    float tMin = max(max(tMinVec.x, tMinVec.y), tMinVec.z),
    tMax = min(min(tMaxVec.x, tMaxVec.y), tMaxVec.z);
    
    return tMax > max(tMin, 0.0);
}

vec3 RayTraceBVH(Ray ray)
{
    float t = (ray.direction.y + 1.0) * 0.5, closestT = 1e20;
    vec3 color = (1.0 - t) * vec3(1.0, 1.0, 1.0) + t * vec3(0.5, 0.7, 1.0);

    int queue[1000], l = 0, r = 1; 
    queue[0] = 0; 

    int rayID = int(gl_FragCoord.y) * 800 + int(gl_FragCoord.x); 
    aabbCollisionCounts[rayID] = 0; 

    while (l < r)
    {
        int cnt = queue[l++];
        if (!RayAABBIntersect(ray, bvhNodes[cnt].aabbMin, bvhNodes[cnt].aabbMax)) continue;

        aabbCollisionCounts[rayID]++;

        if (bvhNodes[cnt].count == 0)
        {
            if (RayAABBIntersect(ray, bvhNodes[bvhNodes[cnt].left].aabbMin, bvhNodes[bvhNodes[cnt].left].aabbMax)) 
                queue[r++] = bvhNodes[cnt].left;
            if (RayAABBIntersect(ray, bvhNodes[bvhNodes[cnt].right].aabbMin, bvhNodes[bvhNodes[cnt].right].aabbMax)) 
                queue[r++] = bvhNodes[cnt].right;
        }
        else
        {
            for (int i = bvhNodes[cnt].left; i < bvhNodes[cnt].right; i++)
            {
                vec3 hitPoint;
                if (RayTriangleIntersect(ray, triangles[i], t, hitPoint))
                {
                    if (t >= closestT) continue;
                    vec3 lightPos = vec3(10.0, 10.0, 10.0);
                    vec3 lightDir = normalize(lightPos - hitPoint);
                    float diff = max(dot(triangles[i].n, lightDir), 0.0);
                    color = vec3(0.8) * diff; 
                    closestT = t;
                }
            }
        }
    }

    return color;
}

void main()
{
    float u = screenCoord.x, v = screenCoord.y;

    Ray ray = CreateRay(camera.position, camera.forward + 4 * (u - 0.5) * camera.right + 3 * (v - 0.5) * camera.up);
    
    //FragColor = vec4(1.0, 1.0, 1.0, 1.0);
    //FragColor = vec4(vec3(bvhNodes[0].left), 1.0);
    //FragColor = vec4(RayTrace(ray), 1.0);
    FragColor = vec4(RayTraceBVH(ray), 1.0);
}