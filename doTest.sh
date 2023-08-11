kind create cluster --config testing-conf.yaml
nodes=$(kubectl get nodes --template='{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
while IFS= read -r nodeName; do
    kubectl taint node $nodeName node-role.kubernetes.io/control-plane:NoSchedule-
done <<< "$nodes"
# Automatic pull and load of Docker images for simplicity
kind load docker-image intel/video-analytics-serving:latest
kind load docker-image jellyfin/jellyfin:latest
kind load docker-image linuxserver/grav:latest
kind load docker-image mistplat/jellyfinrequest:latest
kind load docker-image mistplat/gravrequest:latest
kind load docker-image mistplat/intelairequest:latest
echo "Iteration,Date tag,Start time,End time,Time taken (s)" >> ./TestResultInfo/PlatformTimingReport.csv
startTime=$(date "+%s")
iterCounter=0
. .venv/bin/activate
while [ $(expr $(date "+%s") - $startTime) -le 3600 ]; do
    dateTag=$(date "+%y-%m-%d-%H-%M-%S")
    iterStart=$(date "+%s")
    cd kubernetes_delegation
    ./getDeviceInfo.sh
    cp ./nodes.yaml ../TestResultInfo/nodes-$dateTag.yaml
    cd ..
    cd Optimizer
    python3 optimizer_ui.py -n ../kubernetes_delegation/nodes.yaml -r ../TestingBaseline/requests.yaml -s ../TestingBaseline/services.yaml -cs ../TestingBaseline/container_specs.yaml -p ../TestingBaseline/service_ports.yaml -o ../testing-autogen-serv-kubeconf.yaml --dfo ../TestResultInfo/solution-df-$dateTag.csv
    cd ..
    kubectl apply -f testing-autogen-serv-kubeconf.yaml
    cp testing-autogen-serv-kubeconf.yaml ./TestResultInfo/testing-autogen-serv-kubeconf-$dateTag.yaml
    cd RequestKube
    python3 r2k_ui.py -r ../TestingBaseline/requests.yaml -cs ../TestingBaseline/request_specs.yaml -o ../testing-autogen-cli-kubeconf.yaml
    cd ..
    kubectl apply -f testing-autogen-cli-kubeconf.yaml
    cp testing-autogen-cli-kubeconf.yaml ./TestResultInfo/testing-autogen-cli-kubeconf-$dateTag.yaml
    iterEnd=$(date "+%s")
    echo "$iterCounter,$dateTag,$iterStart,$iterEnd,$(expr $iterEnd - $iterStart)" >> ./TestResultInfo/PlatformTimingReport.csv
    iterCounter=$(expr $iterCounter + 1)
    
    iterTime=$(expr $(date "+%s") - $iterStart)
    iterLeft=$(expr 300 - $iterTime)
    if [ $iterLeft -ge 0 ]; then
        sleep $iterLeft
    fi
done
kind delete cluster
cp -a /tmp/hostpath-provisioner/* ./TestResultInfo