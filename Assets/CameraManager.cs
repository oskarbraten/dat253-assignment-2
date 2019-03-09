using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

[ExecuteInEditMode]
public class CameraManager : MonoBehaviour
{
    private new Camera camera;
    private Material material;

    void Start()
    {
        camera = gameObject.GetComponent<Camera>();
        material = GameObject.Find("Image").GetComponent<Image>().material;
    }

    void Update()
    {

        material.SetVector("_CameraForward", camera.transform.forward);
        material.SetVector("_CameraUp", camera.transform.up);
        material.SetFloat("_CameraFOV", camera.fieldOfView);
    }
}
