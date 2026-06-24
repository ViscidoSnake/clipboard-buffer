PREFIX ?= /usr/local

x11_bsd_flags = -I/usr/X11R6/include -L/usr/X11R6/lib

all:
	${CC} ${CFLAGS} ${LDFLAGS} cpd.c -o cpd $(x11_bsd_flags) -lX11 -lXfixes
