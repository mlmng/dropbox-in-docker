Dropbox in Docker
=================

Install Dropbox inside Docker.

How to Install
--------------

Run the following command.  This command will show a URL to activate Dropbox.  Once you activate Dropbox during running the command, you should kill it because it runs a temporary container just for activating Dropbox.

```sh
git clone https://github.com/mlmng/dropbox-in-docker dropbox-in-docker
cd dropbox-in-docker && make install
```

How to Use dropbox-in-docker
-------------------------

Run the following command:

```sh
make install
```
