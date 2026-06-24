#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xfixes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

void die(const char *s) {
  perror(s);
  exit(1);
}

int main(int argc, char *argv[]) {
    
    Display *disp;
    Window root;
    Atom clip;
    XEvent evt;
    int opt;

    static int loop = 1;
    int selections = (1 << 0); //clipboard
    char* logfile = "./cpd-log.log";
    char* bufferfileA = "/dev/shm/cpdA.b";
    char* bufferfileB = "/dev/shm/cpdB.b";
    int count = 1;

    FILE *fp;
    FILE *fb;
    
    disp = XOpenDisplay(NULL);
    if (!disp) die("can't open X display\n");

    root = DefaultRootWindow(disp);

    clip = XInternAtom(disp, "CLIPBOARD", False);

    XFixesSelectSelectionInput(disp, root, clip, XFixesSetSelectionOwnerNotifyMask);
    
    (void)setvbuf(stdout, NULL, _IONBF, 0);

    do {
        
        XNextEvent(disp, &evt); // suppongo che il codice si blocchi qui
        
        FILE *fp;
        char buffer[1024];
        int i, ch;

        // Eseguiamo xclip in modalità lettura (-o)
        // "r" significa che vogliamo LEGGERE l'output del comando
        fp = popen("xclip -o -selection clipboard 2>/dev/null", "r");
        if (fp == NULL) die("error in popen");
        
        for (i = 0; (i < (sizeof(buffer)-1) && ((ch = fgetc(fp)) != EOF)); i++)
            buffer[i] = ch;
     
        buffer[i] = '\0';
        if (fclose(fp)) die("errore to close command buffer");
          
        FILE *fb;
        if (count == 10){
            fb = fopen(bufferfileB, "w");
            if (fb == NULL) die("error to open file buffer");
            if (fclose(fb)) perror("error to close file buffer");
            fb = fopen(bufferfileA, "ab+");
            if (fb == NULL) die("error to open file buffer");
            if(!fprintf(fb, "%s%c", buffer, '\0')) die("error to write file buffer");
            count++;
        } else if (count == 20){
            fb = fopen(bufferfileA, "w");
            if (fb == NULL) die("error to open file buffer");
            if (fclose(fb)) perror("error to close file buffer");
            fb = fopen(bufferfileB, "ab+");
            if (fb == NULL) die("error to open file buffer");
            if(!fprintf(fb, "%s%c", buffer, '\0')) die("error to write file buffer");
            count = 1;
        } else if (count < 10){
            fb = fopen(bufferfileA, "ab+");
            if (fb == NULL) die("error to open file buffer");
            if(!fprintf(fb, "%s%c", buffer, '\0')) die("error to write file buffer");
            count++;
        } else if (count > 10){
            fb = fopen(bufferfileB, "ab+");
            if (fb == NULL) die("error to open file buffer");
            if(!fprintf(fb, "%s%c", buffer, '\0')) die("error to write file buffer");
            count++;
        }
        if (fclose(fb)) perror("error to close file buffer");
        

    } while (1);
    
    XCloseDisplay(disp);
    
    return 0;
}








// comando per estrarre dal file buffer le stringhe
// awk -v RS='\0' 'NR==2 {print; exit}' cpd.d
//  
// 
// 
// comando per avviare lo script e inviare gli errori nel file di log
// ./cpd 2>> cpd-error.log







