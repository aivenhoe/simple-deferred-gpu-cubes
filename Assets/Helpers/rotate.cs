using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class rotate : MonoBehaviour
{
    public float rotateX = 0.4f;
    public float rotateY = 0.1f;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        transform.Rotate(rotateX, rotateY, 0); 
    }
}
