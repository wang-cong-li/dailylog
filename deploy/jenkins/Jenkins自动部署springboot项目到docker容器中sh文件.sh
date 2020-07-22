#!bin/bash
echo "args:$@"

removeContainer(){
   echo "删除容器:$1"
   docker stop "$1" && docker rm "$1"
}

createContainer(){
   echo "容器名称:$1,端口:$2,镜像:$3,服务名称:$4"
   docker run -itd --name="$1" --restart=always -v /usr/dockersoft/springboot-demo/data:/mapfile -e PASSWORD=123456  -e SERVER_NAME="$4" -p "$2":8080 "$3"
}


createImage(){
  echo "镜像名称:$1"
  docker build -t "$1" .
}

removeImage(){
  echo "删除容器:$1"
  docker rmi -f "$1"
}

#容器存在，删除并创建容器

delAndCreateContainer(){
   #$1删除容器名 $2删除镜像名 $3创建镜像名 $4创建容器名 $5端口
   removeContainer "$1"
   removeImage  "$2"
   createImage "$3"
   createContainer "$4" "$5" "$3" "$6"
}

delAndCreateContainer "$2" "$3" "$4" "$5" "$6" "$7"  #删除容器名 删除镜像名 创建镜像名  创建容器名 端口 服务名称
