#include "AcceleratedRayTracer.h"

const int width = 800, height = 600; 
int cnt, frameCnt; bool f; float lastTime, currentTime, lastx, lasty;
vector<FlattenedBVHNode> flattenedBVH;
Camera camera(vec3(0.0f, 0.35f, 0.7f), vec3(0.0f, 0.35f, 0.0f), vec3(0.0f, 1.0f, 0.0f));

void mouse_callback(GLFWwindow* window, double xpos, double ypos)
{
    if (!f) { f = 1; lastx = xpos, lasty = ypos; return; }
    float daltax = xpos - lastx, daltay = ypos - lasty;
    lastx = xpos, lasty = ypos;
    camera.ProcessMouseMovement(daltax, daltay);
}

int main() 
{
    if (!glfwInit()) 
    {
        cerr << "Failed to initialize GLFW" << endl;
        return -1;
    }
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow* window = glfwCreateWindow(width, height, "Ray Tracing", nullptr, nullptr);
    if (!window) 
    {
        cerr << "Failed to create GLFW window" << endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window); 
    glfwSetCursorPosCallback(window, mouse_callback);

    glewExperimental = GL_TRUE;
    if (glewInit() != GLEW_OK) 
    {
        cerr << "Failed to initialize GLEW" << endl;
        glfwTerminate();
        return -1;
    }

    glViewport(0, 0, width, height);

    Shader shader("VertexShader.glsl", "FragmentShader.glsl");

    Model model;
    if (!model.LoadModel("Bunny_High.obj")) 
    {
        cerr << "Failed to load model" << endl;
        return -1;
    }

    auto rootBVH = model.BuildBVH(0, model.triangles.size());
    model.SerializeBVH(flattenedBVH, rootBVH);

    uint VAO, VBO, EBO, SSBO, BVHSSBO, CollisionSSBO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    glGenBuffers(1, &EBO);

    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(screenVertices), screenVertices, GL_STATIC_DRAW);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(screenIndices), screenIndices, GL_STATIC_DRAW);

    glGenBuffers(1, &SSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, SSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(Triangle) * model.triangles.size(), &model.triangles[0], GL_STATIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, SSBO);
    
    glGenBuffers(1, &BVHSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, BVHSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(FlattenedBVHNode) * flattenedBVH.size(), &flattenedBVH[0], GL_STATIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, BVHSSBO);

    int pixelCount = width * height;
    glGenBuffers(1, &CollisionSSBO);
    glBindBuffer(GL_SHADER_STORAGE_BUFFER, CollisionSSBO);
    glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(int) * pixelCount, NULL, GL_DYNAMIC_DRAW);
    glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, CollisionSSBO);

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);
    glBindVertexArray(0);

    while (!glfwWindowShouldClose(window)) 
    {
        cnt++; frameCnt++; currentTime = glfwGetTime();
        if (currentTime - lastTime >= 1.0) 
        { 
            double fps = frameCnt / (currentTime - lastTime);
            stringstream ss;
            ss << "Ray Tracing - FPS: " << fps;
            glfwSetWindowTitle(window, ss.str().c_str());
            frameCnt = 0; lastTime = currentTime;
        }

        if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS) glfwSetWindowShouldClose(window, true);
        if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS) camera.position += vec3(0.05) * normalize(camera.forward);
        if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS) camera.position -= vec3(0.05) * normalize(camera.right);
        if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS) camera.position -= vec3(0.05) * normalize(camera.forward);
        if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS) camera.position += vec3(0.05) * normalize(camera.right);
        if (glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS) camera.position += vec3(0.05) * normalize(camera.up);
        if (glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS) camera.position -= vec3(0.05) * normalize(camera.up);
        if (glfwGetKey(window, GLFW_KEY_C) == GLFW_PRESS && cnt > 100)
        {
            cnt = 0; vector<int> aabbCollisions(pixelCount);
            glBindBuffer(GL_SHADER_STORAGE_BUFFER, CollisionSSBO);
            int* ptr = (int*)glMapBuffer(GL_SHADER_STORAGE_BUFFER, GL_READ_ONLY);
            memcpy(aabbCollisions.data(), ptr, sizeof(int)* pixelCount);
            glUnmapBuffer(GL_SHADER_STORAGE_BUFFER);

            int num = 0, minNum = 1e9, maxNum = -1e9;
            for (int count : aabbCollisions) 
            {
				num += count; minNum = std::min(minNum, count); maxNum = std::max(maxNum, count);
            }
            printf("Avg: %d, Min: %d, Max: %d\n", num / pixelCount, minNum, maxNum);
        }

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

        shader.use();

        shader.SetUniformVec3("camera.position", camera.position);
        shader.SetUniformVec3("camera.forward", camera.forward);
        shader.SetUniformVec3("camera.right", camera.right);
        shader.SetUniformVec3("camera.up", camera.up);
        shader.SetUniform1i("triangleCount", model.triangles.size());
        shader.SetUniform1i("bvhCount", flattenedBVH.size());

        glBindVertexArray(VAO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }
    glfwTerminate();
}