PREFIX ?= /usr/local
SYSTEMD = /home/quelviscidosnake/.config/systemd/user

x11_bsd_flags = -I/usr/X11R6/include -L/usr/X11R6/lib

all:
	${CC} ${CFLAGS} ${LDFLAGS} cpd.c -o cpd $(x11_bsd_flags) -lX11 -lXfixes

install: all
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f cpd ${DESTDIR}${PREFIX}/bin
	chmod 755 ${DESTDIR}${PREFIX}/bin/cpd
	cp -f cpd.service ${SYSTEMD}
	
uninstall:
	rm -f ${DESTDIR}${PREFIX}/bin/cpd
	rm -f cpd.service ${SYSTEMD}