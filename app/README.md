# A demo app

```
export PS1='$ '
```

Roll out changes using Kubernetes:

```
$ git clone https://github.com/lukemarsden/demo-app
$ cd demo-app
$ kubectl apply -f demo-app-rc-blue.yaml
replicationcontroller "demo-app-blue" created
```

Go to `<cluster-ip>:3000` in your browser.

```
$ kubectl rolling-update --update-period=5s demo-app-blue -f demo-app-rc-green.yaml
Created demo-app-green
Scaling up demo-app-green from 0 to 8, scaling down demo-app-blue from 8 to 0 (keep 8 pods available, don't exceed 9 pods)
[...]
```

Reload your browser a few times.
