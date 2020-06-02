# Installing and using code-server on Kubernetes

- [1. Obtain a Kubernetes Cluster](#1-obtain-a-kubernetes-cluster)
- [2. Create code-server container image ](#2-create-code-server-container-image)  
  - [Build Image](#build-image)
  - [Push Image](#push-image)
- [3. Install code-server on Kubernetes](#3-install-code-server-on-kubernetes)
- [4. Using code-server on Kubernetes](#4-using-code-server-on-kubernetes)
- [5. Import an existing GitHub project](#5-import-an-existing-github-project)

## 1. Obtain a Kubernetes Cluster

This installation guide is based on the assumption that you have access to a Kubernetes cluster to install `code-server` and that it can accessed using the Kubernetes CLI - [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/).  Any flavor of Kubernetes will work, in this example, `code-server` will be installed on VMware Enterprise PKS which is running on top of Google Cloud (GCP).  

## 2. Create code-server container image

In order to deploy `code-server` to Kubernetes, a [Docker container image](https://www.docker.com/resources/what-container) needs to be created that will run the `code-server` application.  After the container image is built, it will need to be pushed to a container image repository like [DockerHub](https://hub.docker.com/) or [Harbor](https://goharbor.io/).  In this example, the container image will be pushed to DockerHub.  

**NOTE:** This step is not required because you could use the prebuilt container image that already exists on DockerHub for `code-server`, located at `codercom/code-server:latest`.

### Build Image

To create a Docker container image you need to create a `Dockerfile` which defines how the container image is built.  In our example, you want the container image to run `code-server`.  In a project working directory, create a file named `Dockerfile` with no extension and copy the contents below into it.  At a high-level, the `Dockerfile` below is creating a Docker container image based on Debian O/S, installing utilities: (git, curl rsync, unzip), downloading and installing `code-server`, adding the `coder` user, setting the port and defining the working directory. The final line, `ENTRYPOINT` is defining how the container image will run, in our example, you are launching `code-server` and setting the binding port.

The [Dockerfile reference](https://docs.docker.com/engine/reference/builder/) provides more details about creating Docker container images and using a `Dockerfile`.

```
FROM debian:10

RUN apt-get update

# Install misc build dependencies
RUN apt-get install -y curl git rsync unzip

# Install code-server
RUN curl -fOL https://github.com/cdr/code-server/releases/download/v3.4.0/code-server_3.4.0_amd64.deb
RUN dpkg -i code-server_3.4.0_amd64.deb
RUN rm code-server_3.4.0_amd64.deb

# Setup user
RUN adduser --gecos '' --disabled-password coder
RUN chown -Rh coder:coder /home/coder

WORKDIR /home/coder

USER coder

EXPOSE 8080

ENTRYPOINT code-server --bind-addr 0.0.0.0:8080 .
```

The `Dockerfile` is located [here](dockerfiles/Dockerfile).

Once the `Dockerfile` file is created, you can build the container image.  This creates the Docker container image locally on your machine.  

`docker build -t code-server:latest .`

View the list of Docker container images on your local machine.

```
docker images
REPOSITORY         TAG          IMAGE ID          CREATED             SIZE
code-server        latest       18aac58c7475      24 hours ago        670MB
...
```

### Push Image

The Docker container image that was just built needs to be pushed to a container image repository.  In this example, the container image will be pushed to [DockerHub](https://hub.docker.com/)

In order to push the container image, you need to tag the local image to match the format of how it's stored on DockerHub, which follows the convention {your-docker-username}/{image-name}:{tagname}

`docker tag code-server:latest {your-docker-username}/code-server:latest`

Push the container image to DockerHub.

`docker push {your-docker-username}/code-server:latest`

## 3. Install code-server on Kubernetes

Now that the Docker container image is built and pushed to DockerHub, you are ready to install `code-server` on Kubernetes.  First, create a Kubernetes [PersistentVolume and PersistentVolumeClaim](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).  The purpose of creating these Kubernetes resources is to allow the source data of the projects in `code-server` to be persisted.  Otherwise, the data will be lost when the `code-server` Pod is restarted or deleted.  A [Pod](https://kubernetes.io/docs/concepts/workloads/pods/pod-overview/) is a Kubernetes resource to run our application, in this case `code-server`.

Copy and paste the following lines to create the required PersistentVolume and PersistentVolumeClaim on the command line.  The Kubernetes manifest to create both is located [here](deployment/code-server-pv.yaml).  

```
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-code-server
spec:
  capacity:
    storage: 500Mi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  hostPath:
    path: /var/vcap/code-server
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-code-server
spec:
  accessModes:
    - ReadWriteOnce
  volumeName: pv-code-server
  resources:
    requests:
      storage: 50Mi
  storageClassName: standard
EOF
```

Create the Kubernetes Pod to run `code-server`.  Copy the following lines below into your favorite editor and change the `image:` line to reference the location of where your container image resides; this was done in the [Push Image](#push-image) step.  The Kubernetes manifest to create the Pod is located [here](deployment/code-server.yaml).

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: code-server
  name: code-server
spec:
  containers:
  - name: code-server
    image: {your-docker-username}/code-server:latest
    ports:
    - containerPort: 8080
EOF
```

Once the `code-server` Pod is up and running, you can use `kubectl port-forward` to view the `code-server` UI.  Using the technique of [Kubernetes Port Forward]((https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/)) allows a local port to access a port on a Kubernetes Pod without creating a Kubernetes Service.  Another way to expose access to `code-server` would be to create a Kubernetes Service of type LoadBalancer.  This will create an external IP address that could be used by anyone.  For more details visit [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/).  A example Kubernetes manfiest to create the service is located [here](deployment/code-server-service.yaml).

```
kubectl get pod code-server -w
NAME          READY   STATUS    RESTARTS   AGE
code-server   1/1     Running   0          1m
```

## 4. Using code-server on Kubernetes

Once the Pod is in a `Running` status, use the `kubectl port-forward` command to gain access to `code-server`.  A shell script to run the port forward is located [here](utils/portForward.sh).

```
kubectl port-forward code-server 8080:8080
```

Go to your browser and enter `http://localhost:8080`

![Login](assets/code-server-login.png)

The password for `code-server` can be found by running the following command.  A shell script to get the password is located [here](utils/getPassword.sh).

```
kubectl exec -it code-server  cat /home/coder/.config/code-server/config.yaml |  grep password: | awk '{print $2}'
f461d8aabb0d1d7b7d28a204
```

![Image of Running VSCode](assets/code-server.png)

Congratulations, you have successfully installed `code-server` on Kubernetes!

## 5. Import an existing GitHub project

Import an existing GitHub project, add some additional logic to the application and commit the changes.

First, open a terminal session and set the following git values.

```
git config --global user.name "{your.github.username}"
git config --global user.email "{your.email.address}"
```

Using the Command Palette or the Terminal Window, clone an existing GitHub project.  For this example, you will clone a SpringBoot RESTful Web Service project.  The format of the Git clone includes our username and GitHub [token](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line).

```
git clone https://yourgithubusername:token@github.com/decelc-pivotal/spring-demo-project
```

Once the project is cloned you are ready to make some changes and then commit/push the changes back to the GitHub repository.
