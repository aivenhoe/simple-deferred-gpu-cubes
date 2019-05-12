using UnityEngine;
using UnityEngine.Rendering;
using System.Runtime.InteropServices;


//great help from here, i.e. where to inject commandbuffers: https://github.com/przemyslawzaworski/Unity3D-CG-programming/blob/master/point_cloud_with_shadow.cs

public struct Point
{
    public Vector3 vertex;
    public Vector3 normal;
    public Vector4 tangent;
    public Vector2 uv;
    public Vector4 color;
    public Vector2 uvHeight; //passing a separate uv so the shader knows where to sample heighttex
}
public class CubePool : MonoBehaviour
{
    public Material material;
    private ComputeBuffer verticesBuffer;
    CommandBuffer camera_command_buffer;
    CommandBuffer light_command_buffer;
    public Camera camera_source;
    public Light light_source;
    public int resX = 4;
    public int resY = 4;
    public float range = 20f;

    Vector3[] vertices = {
            new Vector3 (0, 0, 0), //0
            new Vector3 (1, 0, 0), //1
            new Vector3 (1, 1, 0), //2
            new Vector3 (0, 1, 0), //3
            new Vector3 (0, 1, 1), //4
            new Vector3 (1, 1, 1), //5
            new Vector3 (1, 0, 1), //6
            new Vector3 (0, 0, 1), //7
        };
    Vector3[] uvs = {
            new Vector2 (0, 0), 
            new Vector2 (1, 1),
            new Vector2 (1, 0),
            new Vector2 (0, 0),
            new Vector2 (0, 1),
            new Vector2 (1, 1)

        };
    int[] triangles = {
            0, 2, 1, //face front
			0, 3, 2,
            3, 5, 2, //face top
			3, 4, 5,
            1, 5, 6, //face right
			1, 2, 5,
            7, 3, 0, //face left
			7, 4, 3,
            6, 4, 7, //face back
			6, 5, 4,
            7, 1, 6, //face bottom
			7, 0, 1
        };
    Color[] cols =
    {
            Color.red,
            Color.green,
            Color.blue,
            Color.red,
            Color.white,
            Color.green
    };

    //just a function to get a all the data for one cube at once
    public void GetCube(out Vector3[] myVertices, out Vector3[] myNormals, out Vector4[] myTangents, out Vector2[] myUVs, out Color[] myCols)
    {
        Vector3[] v = new Vector3[triangles.Length];
        Vector2[] u = new Vector2[triangles.Length];
        Vector3[] n = new Vector3[triangles.Length];
        Vector4[] t = new Vector4[triangles.Length];
        Color[] c = new Color[triangles.Length];
        for (int i = 0; i < triangles.Length; i++)
        {
            v[i] = vertices[triangles[i]];
            u[i] = uvs[i%uvs.Length];
            c[i] = cols[i % cols.Length];
        }
        for (int i = 0; i < t.Length; i++)
            t[i] = new Vector4(Random.value, Random.value, Random.value, Random.value); //no idea how to calculate tangents. 


        for (int i = 0; i<vertices.Length; i++)
        {
            Vector3 side1 = vertices[triangles[i * 3 + 1]] - vertices[triangles[i * 3 + 0]];
            Vector3 side2 = vertices[triangles[i * 3 + 2]] - vertices[triangles[i * 3 + 0]]; ;
            Vector3 side3 = vertices[triangles[i * 3 + 2]] - vertices[triangles[i * 3 + 1]];
            Vector3 perp1 = Vector3.Cross(side1, side2);
            Vector3 perp2 = Vector3.Cross(side1, side3);
            Vector3 perp3 = Vector3.Cross(side2, side3);
            perp1 /= perp1.magnitude;
            perp2 /= perp2.magnitude;
            perp3 /= perp3.magnitude;
            n[i*3+0] = perp1;
            n[i * 3 + 1] = perp2;
            n[i * 3 + 2] = perp3;

        }
        myVertices = v;
        myUVs = u;
        myCols = c;
        myTangents = t;
        myNormals = n;

    }

private void Start()
    {
        int nVerticesPerCube = 36; //its just like that.
        int nVertices = nVerticesPerCube * resX*resY;
        Point[] allVertices = new Point[nVertices];
        int cubeCounter = 0;

        Vector3 cubeScale = new Vector3(range / (float)resX, range/(float)resY, range / (float)resY); //calculating size of each cublet according to range and resX & resY

        //iterating through each cubeposition with resX & resY aka columns/rows
        for (int j = 0; j < resY; j++)
        {
            for (int k = 0; k < resX; k++)
            {
                cubeCounter = (j*resY + k) * nVerticesPerCube;
                Vector3 posOffset = new Vector3(j * (range / resX) - range/2f, 0, k * (range / resY) - range/2f); //defining posiition for each cublet

                //getting cube data
                GetCube(out Vector3[] verts, out Vector3[] norms, out Vector4[] tangs, out Vector2[] uvvs, out Color[] colz);

                //iterating through the data we got from the function above and write it into allVertices array.
                for (int i = 0; i < verts.Length; i++)
                {
                    Vector3 vp = new Vector3(verts[i].x * cubeScale.x, verts[i].y * cubeScale.y, verts[i].z * cubeScale.z);
                    allVertices[cubeCounter + i].vertex = vp + posOffset;
                    allVertices[cubeCounter + i].uv = uvvs[i];
                    allVertices[cubeCounter + i].normal = norms[i];
                    allVertices[cubeCounter + i].tangent = tangs[i];
                    allVertices[cubeCounter + i].color = colz[i];
                    allVertices[cubeCounter + i].uvHeight = new Vector2((float)k / (float)resX, (float)j / (float)resY);
                }
            }
        }
        //writing verticesBuffer to material/shader
        verticesBuffer = new ComputeBuffer(allVertices.Length, Marshal.SizeOf(allVertices.GetType().GetElementType()));
        verticesBuffer.SetData(allVertices);
        material.SetBuffer("points", verticesBuffer);

        //tell renderenging when to draw geometry
        camera_command_buffer = new CommandBuffer();
        camera_command_buffer.DrawProcedural(Matrix4x4.identity, material, 0, MeshTopology.Triangles, nVertices);
        camera_source.AddCommandBuffer(CameraEvent.BeforeGBuffer, camera_command_buffer);

        //tell renderengine when to draw geometry for shadow pass
        light_command_buffer = new CommandBuffer();
        light_command_buffer.DrawProcedural(Matrix4x4.identity, material, 1, MeshTopology.Triangles, nVertices);
        light_source.AddCommandBuffer(LightEvent.BeforeShadowMapPass, light_command_buffer);
    }

    private void OnDestroy()
    {
        verticesBuffer.Dispose();
    }
}
