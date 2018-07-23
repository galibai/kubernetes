apiVersion: v1
kind: Service
metadata:
  name: zk-svc
  namespace: bi-prod
  labels:
    zk-name: zk
    component: zk
  annotations:
    service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"
spec:
  ports:
  - port: 2181
    name: zkclient
  - port: 2888
    name: zkserver
  - port: 3888
    name: zkleader
  clusterIP: None
  selector:
    zk-name: zk
---
apiVersion: apps/v1beta1
kind: StatefulSet
metadata:
  name: zk
  namespace: bi-prod
  labels:
    zk-name: zk
    component: zk
spec:
  selector:
    matchLabels:
      zk-name: zk
  serviceName: "zk-svc"
  replicas: 3
  template:
    metadata:
      labels:
        zk-name: zk
        component: zk
      annotations:
          scheduler.alpha.kubernetes.io/affinity: >
              {
                "podAntiAffinity": {
                  "requiredDuringSchedulingIgnoredDuringExecution": [{
                    "labelSelector": {
                      "matchExpressions": [{
                        "key": "zk-name",
                        "operator": "In",
                        "values": ["zk"]
                      }]
                    },
                    "topologyKey": "kubernetes.io/hostname"
                  }]
                }
              }
    spec:
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: zk
        imagePullPolicy: Always
        image: registry.cn-beijing.aliyuncs.com/icsoc/zookeeper3.4.11
        resources:
          requests:
            memory: 400Mi
            cpu: 0.3
          limits:
            memory: 1Gi
            cpu: 1
        ports:
        - containerPort: 2181
          name: zkclient
        - containerPort: 2888
          name: zkserver
        - containerPort: 3888
          name: zkleader
        env:
        - name: ZOO_REPLICAS
          value: "3"
        - name: JAVA_ZK_JVMFLAG
          value: "\"-Xmx1G -Xms1G\""
        readinessProbe:
          exec:
            command:
            - zk_status.sh
          initialDelaySeconds: 20
          timeoutSeconds: 10
        livenessProbe:
          exec:
            command:
            - zk_status.sh
          initialDelaySeconds: 20
          timeoutSeconds: 10
        volumeMounts:
        - name: datadir
          mountPath: /opt/zookeeper/data
        - name: datalogdir
          mountPath: /opt/zookeeper/data-log
  volumeClaimTemplates:
  - metadata:
      name: datadir
      #annotations:
      #  volume.alpha.kubernetes.io/storage-class: anything
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 5Gi
  - metadata:
      name: datalogdir
      #annotations:
      #  volume.alpha.kubernetes.io/storage-class: anything
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 5Gi
