#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xfixes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

FILE *fb = NULL;

void die(const char *s, const char *serrno) {
    if(serrno==NULL) fprintf(stderr, "<3> ERROR: %s\n", s);
    else fprintf(stderr, "<3> ERROR: %s\n, errno error string: %s\n", s, serrno);

    if(fb != NULL) fclose(fb);
    exit(1);
}

int main() {
    Display *disp;
    Window root, my_win;
    Atom clip, target_utf8, property;
    XEvent evt;
    int xfixes_event_base, xfixes_error_base;

    char* bufferfileA = "/run/user/1000/clipboard-buffer/cpdA.b";
    char* bufferfileB = "/run/user/1000/clipboard-buffer/cpdB.b";
    int count = 1;

    disp = XOpenDisplay(NULL);
    if (!disp) die("can't open X display\n", NULL);

    if (!XFixesQueryExtension(disp, &xfixes_event_base, &xfixes_error_base)) {
        die("XFixes extension not available\n", NULL);
    }

    root = DefaultRootWindow(disp);

    // CREAZIONE DI UNA FINESTRA INVISIBILE DEDICATA
    // Creiamo una finestra elementare che serve solo a ricevere gli eventi della clipboard
    my_win = XCreateSimpleWindow(disp, root, 0, 0, 1, 1, 0, 0, 0);

    clip = XInternAtom(disp, "CLIPBOARD", False);
    target_utf8 = XInternAtom(disp, "UTF8_STRING", False);
    property = XInternAtom(disp, "XSEL_DATA", False);

    // Chiediamo a XFixes di mandare le notifiche di cambio clipboard alla NOSTRA finestra
    XFixesSelectSelectionInput(disp, my_win, clip, XFixesSetSelectionOwnerNotifyMask);
    
    (void)setvbuf(stdout, NULL, _IONBF, 0);

    while (1) {
        XNextEvent(disp, &evt);

        // 1. Il proprietario della clipboard è cambiato
        if (evt.type == xfixes_event_base + XFixesSelectionNotify) {
            XFixesSelectionNotifyEvent *sev = (XFixesSelectionNotifyEvent *)&evt;
            
            // Se siamo stati noi a cambiare la clipboard, ignoriamo
            if (sev->owner == my_win) continue;

            // Richiediamo la conversione specificando la NOSTRA finestra come target
            XConvertSelection(disp, clip, target_utf8, property, my_win, sev->timestamp);
            XFlush(disp);
        }
        
        // 2. I dati convertiti sono pronti sulla nostra finestra
        else if (evt.type == SelectionNotify) {
            XSelectionEvent *sev = &evt.xselection;
            
            if (sev->property == None) {
                // Il proprietario della clipboard non è riuscito a convertire in UTF8_STRING
                continue;
            }

            Atom actual_type;
            int actual_format;
            unsigned long nitems, bytes_after;
            unsigned char *prop_data = NULL;

            // Leggiamo la proprietà direttamente dalla nostra finestra privata
            if (XGetWindowProperty(disp, my_win, property, 0, 1024 / 4, False, 
                                   AnyPropertyType, &actual_type, &actual_format, 
                                   &nitems, &bytes_after, &prop_data) == Success) {
                
                if (prop_data != NULL && nitems > 0) {
                    char buffer[1024];
                    size_t len = (nitems < 1023) ? nitems : 1023;
                    memcpy(buffer, prop_data, len);
                    buffer[len] = '\0';

                    // Puliamo la proprietà dalla nostra finestra e liberiamo la memoria
                    XDeleteProperty(disp, my_win, property);
                    XFree(prop_data);

                    // --- LOGICA FILE BUFFER ---
                    if (count == 10){
                        fb = fopen(bufferfileB, "w");
                        if (fb == NULL) die("error to open file buffer B", strerror(errno));
                        if (fclose(fb)) die("error to close file buffer B", strerror(errno));
                        fb = fopen(bufferfileA, "ab+");
                        if (fb == NULL) die("error to open file buffer A", strerror(errno));
                        if(fprintf(fb, "%s%c", buffer, '\0')<0) die("error to write file buffer A", strerror(errno));
                        count++;
                    } else if (count == 20){
                        fb = fopen(bufferfileA, "w");
                        if (fb == NULL) die("error to open file buffer A", strerror(errno));
                        if (fclose(fb)) die("error to close file buffer A", strerror(errno));
                        fb = fopen(bufferfileB, "ab+");
                        if (fb == NULL) die("error to open file buffer B", strerror(errno));
                        if(fprintf(fb, "%s%c", buffer, '\0')<0) die("error to write file buffer B", strerror(errno));
                        count = 1;
                    } else if (count < 10){
                        fb = fopen(bufferfileA, "ab+");
                        if (fb == NULL) die("error to open file buffer A", strerror(errno));
                        if(fprintf(fb, "%s%c", buffer, '\0')<0) die("error to write file buffer A", strerror(errno));
                        count++;
                    } else if (count > 10){
                        fb = fopen(bufferfileB, "ab+");
                        if (fb == NULL) die("error to open file buffer B", strerror(errno));
                        if(fprintf(fb, "%s%c", buffer, '\0')<0) die("error to write file buffer B", strerror(errno));
                        count++;
                    }
                    if (fclose(fb)) die("error to close file buffer", strerror(errno));
                    // --- FINE LOGICA FILE BUFFER ---
                }
            }
        }
    }

    XDestroyWindow(disp, my_win);
    XCloseDisplay(disp);
    return 0;
}