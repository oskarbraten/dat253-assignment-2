using UnityEngine;
using UnityEngine.UI;

public class SphereManager : MonoBehaviour
{
    private Material material;
    const int NUMBER_OF_SPHERES = 40; // max is defined in shader as 500.

    private GameObject[] spheres;

    void Start()
    {
        material = GameObject.Find("Image").GetComponent<Image>().material;

        material.SetInt("_NumberOfSpheres", NUMBER_OF_SPHERES);
        
        GameObject sphereTemplate = GameObject.Find("SphereTemplate");
        spheres = new GameObject[NUMBER_OF_SPHERES];

        for (int i = 0; i < NUMBER_OF_SPHERES; i++)
        {
            GameObject sphere = Instantiate(sphereTemplate);
            sphere.name = "Sphere" + (i + 1);
            sphere.transform.position = new Vector4(Random.Range(-20.0f, 20.0f), Random.Range(-1f, 1f), Random.Range(-20.0f, 20.0f), 1.0f);

            float r = Random.Range(1.0f, 3.0f);

            sphere.transform.localScale = new Vector3(r, r, r);

            SphereMaterial mat = sphere.GetComponent<SphereMaterial>();

            mat.albedo = new Color(Random.Range(0.0f, 1.0f), Random.Range(0.0f, 1.0f), Random.Range(0.0f, 1.0f));

            if (Random.Range(0.0f, 1.0f) > 0.80f)
            {
                mat.type = 2; // 2 = dielectric
            }
            else
            {
                mat.type = (uint) Random.Range(0, 2); // 0 = diffuse, 1 = metal
            }

            mat.fuzz = Random.Range(0.0f, 1.0f);
            mat.refractive_index = Random.Range(1.31f, 2.42f); // Ice to diamond.

            spheres[i] = sphere;
        }

        // setup base sphere (planet):
        var planet = spheres[0];

        planet.name = "Planet";

        planet.transform.position = new Vector4(0.0f, -3000.5f, -1.0f, 1.0f);
        planet.transform.localScale = new Vector3(6000.0f, 6000.0f, 6000.0f);
        var planet_material = planet.GetComponent<SphereMaterial>();
        planet_material.albedo = new Color(0.5f, 0.5f, 0.5f);
        planet_material.type = 0;

        Destroy(planet.GetComponent<Rigidbody>()); // remove its rigid body.
    }

    void Update()
    {
        // upload updated sphere positions.
        Vector4[] position = new Vector4[NUMBER_OF_SPHERES];
        float[] radius = new float[NUMBER_OF_SPHERES];

        Color[] albedo = new Color[NUMBER_OF_SPHERES];
        float[] type = new float[NUMBER_OF_SPHERES];
        float[] fuzz = new float[NUMBER_OF_SPHERES];
        float[] refractive_index = new float[NUMBER_OF_SPHERES];

        for (int i = 0; i < NUMBER_OF_SPHERES; i++)
        {
            GameObject sphere = spheres[i];
            position[i] = sphere.transform.position;
            radius[i] = sphere.transform.localScale.x / 2.0f;

            SphereMaterial material = sphere.GetComponent<SphereMaterial>();
            albedo[i] = material.albedo;
            type[i] = material.type;
            fuzz[i] = material.fuzz;
            refractive_index[i] = material.refractive_index;

        }

        // upload to material:
        material.SetVectorArray("_SpherePosition", position);
        material.SetFloatArray("_SphereRadius", radius);

        material.SetColorArray("_SphereMaterialAlbedo", albedo);
        material.SetFloatArray("_SphereMaterialType", type);
        material.SetFloatArray("_SphereMaterialFuzz", fuzz);
        material.SetFloatArray("_SphereMaterialRefractiveIndex", refractive_index);
    }
}