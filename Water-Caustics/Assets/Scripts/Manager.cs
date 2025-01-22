using UnityEngine;
using UnityEngine.UI;
using System.Collections.Generic;

public class Manager : MonoBehaviour
{
    // Surface & Click/Drag Control
    public float dragRate = 0.1f, rotationRate = 300f;
    public SphereCollider sphere;
    public BoxCollider surface, cube;
    public Transform cameraOrbit;
    public CustomRenderTexture texture;

    CustomRenderTextureUpdateZone[] zones;
    CustomRenderTextureUpdateZone defaultZone, normalZone, waveZone;

    // Material Updater
    public Material[] materials;
    public Vector3 sphereCenter = new Vector3(-0.4f, -0.75f, 0.2f);

    // FPS Display
    public Text text;

    int dragState = 0; // 0: Default, 1: DragBall, 2: DragCamera
    Vector3 bias;

    void Start()
    {
#if UNITY_STANDALONE
        QualitySettings.vSyncCount = 0;
        Application.targetFrameRate = -1;
#elif UNITY_ANDROID   
        dragRate = 0.05f;
        Application.targetFrameRate = 114514;
#endif
        // Init Wave Render Texture
        texture.Initialize();

        defaultZone = new CustomRenderTextureUpdateZone();
        defaultZone.needSwap = true; defaultZone.passIndex = 0;
        defaultZone.updateZoneCenter = new Vector2(0.5f, 0.5f);
        defaultZone.updateZoneSize = new Vector2(1f, 1f);

        waveZone = new CustomRenderTextureUpdateZone();
        waveZone.needSwap = true; waveZone.passIndex = 1;

        normalZone = new CustomRenderTextureUpdateZone();
        normalZone.needSwap = true; normalZone.passIndex = 2;
        normalZone.updateZoneCenter = new Vector2(0.5f, 0.5f);
        normalZone.updateZoneSize = new Vector2(1f, 1f);

        List<CustomRenderTextureUpdateZone> waves = new List<CustomRenderTextureUpdateZone>();
        for (int i = 0; i < 8; i++)
        {
            waveZone.updateZoneSize = new Vector2(-0.1f, -0.1f);
            waveZone.updateZoneCenter = new Vector2(Random.Range(0f, 1f), Random.Range(0f, 1f));
            waves.Add(waveZone);
        }
        zones = waves.ToArray();
    }

    void Update()
    {
        text.text = $"FPS: {(int)(1 / Time.deltaTime)} ({(int)(1000 * Time.deltaTime)}ms)";

        Vector3 inputPosition = Vector3.zero;

#if UNITY_EDITOR || UNITY_STANDALONE
        if (Input.GetMouseButtonDown(0)) { dragState = 0; inputPosition = Input.mousePosition; }
        else if (Input.GetMouseButton(0)) inputPosition = Input.mousePosition;
        else if (Input.GetMouseButtonUp(0)) dragState = 0;
#elif UNITY_ANDROID
        if (Input.touchCount > 0)
        {
            Touch touch = Input.GetTouch(0);
            if (touch.phase == TouchPhase.Began) { dragState = 0; inputPosition = touch.position; }
            else if (touch.phase == TouchPhase.Moved) inputPosition = touch.position;
            else if (touch.phase == TouchPhase.Ended) dragState = 0;
        }
#endif

        if (inputPosition != Vector3.zero)
        {
            Ray ray = Camera.main.ScreenPointToRay(inputPosition); RaycastHit hit;

            if (dragState == 0)
            {
                if (surface.Raycast(ray, out hit, 100f))
                {
                    waveZone.updateZoneSize = new Vector2(-0.1f, -0.1f);
                    waveZone.updateZoneCenter = new Vector2(hit.point.x / 2 + 0.5f, 0.5f - hit.point.z / 2);
                    zones = new CustomRenderTextureUpdateZone[] { defaultZone, waveZone, normalZone };
                }
                else if (sphere.Raycast(ray, out hit, 100f))
                {
                    dragState = 1;
                    bias = Camera.main.WorldToScreenPoint(sphere.bounds.center) - inputPosition;
                }
                else dragState = 2;
            }
            else if (dragState == 1)
            {
                ray = Camera.main.ScreenPointToRay(inputPosition + bias);
                Plane dragPlane = new Plane(Camera.main.transform.forward, sphere.center);
                dragPlane.Raycast(ray, out float dis);
                float[] hits = IntersectRayWithBox(ray);
                if (hits != null)
                    if (hits.Length == 1 || dis < hits[0]) sphereCenter = sphere.center = ray.GetPoint(hits[0]);
                    else if (dis < hits[1]) sphereCenter = sphere.center = ray.GetPoint(dis);
                    else sphereCenter = sphere.center = ray.GetPoint(hits[1]);
                else bias = Camera.main.WorldToScreenPoint(sphere.bounds.center) - inputPosition;

                if (Mathf.Abs(sphereCenter.y) < 0.25f)
                {
                    float radius = (sphereCenter.y < 0 ? 1 : -1) * Mathf.Sqrt(0.0625f - sphereCenter.y * sphereCenter.y);
                    waveZone.updateZoneSize = new Vector2(radius, radius);
                    waveZone.updateZoneCenter = new Vector2(sphereCenter.x / 2 + 0.5f, 0.5f - sphereCenter.z / 2);
                    zones = new CustomRenderTextureUpdateZone[] { defaultZone, waveZone, normalZone };
                }
            }
            else if (dragState == 2)
            {
                float xRotation = -Input.GetAxis("Mouse Y") * rotationRate * Time.deltaTime;
                float yRotation = Input.GetAxis("Mouse X") * rotationRate * Time.deltaTime;
                cameraOrbit.Rotate(xRotation, 0f, 0f, Space.Self);
                cameraOrbit.Rotate(0f, yRotation, 0f, Space.World);
            }
        }

        foreach (var material in materials) material.SetVector("sphereCenter", sphereCenter);

        if (zones != null) { texture.SetUpdateZones(zones); zones = null; }
        else texture.SetUpdateZones(new CustomRenderTextureUpdateZone[] { defaultZone, normalZone });
        texture.Update(1);
    }

    float[] IntersectRayWithBox(Ray ray)
    {
        Vector3 center = new Vector3(0, 0, 0), scale = new Vector3(1.5f, 1.5f, 1.5f);
        Vector3 min = center - scale / 2, max = center + scale / 2, origin = ray.origin, direction = ray.direction;

        float tMin = (min.x - origin.x) / direction.x, tMax = (max.x - origin.x) / direction.x;
        if (tMin > tMax) (tMin, tMax) = (tMax, tMin);

        float tyMin = (min.y - origin.y) / direction.y, tyMax = (max.y - origin.y) / direction.y;

        if (tyMin > tyMax) (tyMin, tyMax) = (tyMax, tyMin); if ((tMin > tyMax) || (tyMin > tMax)) return null;
        if (tyMin > tMin) tMin = tyMin; if (tyMax < tMax) tMax = tyMax;

        float tzMin = (min.z - origin.z) / direction.z, tzMax = (max.z - origin.z) / direction.z;

        if (tzMin > tzMax) (tzMin, tzMax) = (tzMax, tzMin); if ((tMin > tzMax) || (tzMin > tMax)) return null;

        if (tzMin > tMin) tMin = tzMin; if (tzMax < tMax) tMax = tzMax;

        if (tMax < 0) return null;
        if (tMin < 0) return new float[] { tMax };
        return new float[] { tMin, tMax };
    }
}