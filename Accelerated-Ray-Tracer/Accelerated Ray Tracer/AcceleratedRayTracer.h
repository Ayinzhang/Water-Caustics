#pragma once
#define GLM_ENABLE_EXPERIMENTAL
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "RayTraceModels.h"

float screenVertices[] = 
{
	-1.0f, -1.0f, 0.0f,  0.0f, 0.0f,
	 1.0f, -1.0f, 0.0f,  1.0f, 0.0f,
	 1.0f,  1.0f, 0.0f,  1.0f, 1.0f,
	-1.0f,  1.0f, 0.0f,  0.0f, 1.0f 
};
uint screenIndices[] = {
	0, 1, 2,
	2, 3, 0
};

vec3 MinVec3(const vec3& a, const vec3& b)
{
	return vec3(std::min(a.x, b.x), std::min(a.y, b.y), std::min(a.z, b.z));
}

vec3 MaxVec3(const vec3& a, const vec3& b) 
{
	return vec3(std::max(a.x, b.x), std::max(a.y, b.y), std::max(a.z, b.z));
}

struct Shader
{
public:
	string vertexString, fragmentString;
	const char* vertexSource; const char* fragmentSource;
	uint ID, vertex, fragment;
	Shader(const char* vertexPath, const char* fragmentPath)
	{
		ifstream vertexFile, fragmentFile;
		vertexFile.open(vertexPath), fragmentFile.open(fragmentPath);
		stringstream vertexStream, fragmentStream;
		vertexStream << vertexFile.rdbuf(), fragmentStream << fragmentFile.rdbuf();
		vertexString = vertexStream.str(), fragmentString = fragmentStream.str();
		vertexSource = vertexString.c_str(); fragmentSource = fragmentString.c_str();
		glewExperimental = GL_TRUE; glewInit();
		vertex = glCreateShader(GL_VERTEX_SHADER);
		glShaderSource(vertex, 1, &vertexSource, NULL);
		glCompileShader(vertex);
		fragment = glCreateShader(GL_FRAGMENT_SHADER);
		glShaderSource(fragment, 1, &fragmentSource, NULL);
		glCompileShader(fragment);
		ID = glCreateProgram();
		glAttachShader(ID, vertex), glAttachShader(ID, fragment);
		glLinkProgram(ID);
		glDeleteShader(vertex), glDeleteShader(fragment);
	}
	void use() { glUseProgram(ID); }
	void SetUniformMat4(const char* name, mat4 mat)
	{
		glUniformMatrix4fv(glGetUniformLocation(ID, name), 1, GL_FALSE, value_ptr(mat));
	}
	void SetUniformVec2(const char* name, vec2 vector)
	{
		glUniform2f(glGetUniformLocation(ID, name), vector.x, vector.y);
	}
	void SetUniformVec3(const char* name, vec3 vector)
	{
		glUniform3f(glGetUniformLocation(ID, name), vector.x, vector.y, vector.z);
	}
	void SetUniform1f(const char* name, float f)
	{
		glUniform1f(glGetUniformLocation(ID, name), f);
	}
	void SetUniform1i(const char* name, int slot)
	{
		glUniform1i(glGetUniformLocation(ID, name), slot);
	}
};


struct Camera
{
public:
	vec3 position, forward, right, up, worldUp; float yaw, pitch;
	Camera(vec3 _position, vec3 target, vec3 worldup)
	{
		position = _position; worldUp = worldup;
		forward = normalize(target - position);
		right = normalize(cross(forward, worldUp));
		up = -normalize(cross(forward, right));
	}
	Camera(vec3 _position, float pitch, float yaw, vec3 worldup)
	{
		position = _position; worldUp = worldup; pitch = pitch; yaw = yaw;
		forward = vec3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw));
		right = normalize(cross(forward, worldUp));
		up = -normalize(cross(forward, right));
	}
	mat4 GetViewMatrix()
	{
		return lookAt(position, forward + position, worldUp);
	}
	void ProcessMouseMovement(float daltax, float daltay)
	{
		yaw -= 0.01 * daltax; pitch -= 0.01 * daltay;
		UpdateCameraVectors();
	}
	void UpdateCameraVectors()
	{
		forward = vec3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw));
		right = normalize(cross(forward, worldUp));
		up = -normalize(cross(forward, right));
	}
};