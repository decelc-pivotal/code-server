kubectl exec -it code-server cat /home/coder/.config/code-server/config.yaml |  grep password: | awk '{print $2}' 
