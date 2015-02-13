start:
	bash service.sh start
.PHONY: start

stop:
	bash service.sh stop
.PHONY: stop

install:
	echo "original uid:gid = $ORGUID:$ORGGID"
	bash service.sh install
.PHONY: install

uninstall:
	bash service.sh uninstall
.PHONY: uninstall
