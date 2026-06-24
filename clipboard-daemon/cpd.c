#include <X11/Xatom.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xfixes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

FILE *fp = NULL;
FILE *fb = NULL;

void die(const char *s, const char *serrno) {
	// scrivi l'errore sulla stderr
	if(serrno==NULL) fprintf(stderr, "<3> ERROR: %s\n", s);
	else fprintf(stderr, "<3> ERROR: %s\n, errno error string: %s\n", s, serrno);

	// forza la chiusura dei file buffer aperti, devi verificare se prima sono aperti
	if(fp != NULL) pclose(fp);
	if(fb != NULL) fclose(fb);
	
	exit(1);
}

int main() {
	
	Display *disp;
	Window root;
	Atom clip;
	XEvent evt;
	int opt;

	static int loop = 1;
	int selections = (1 << 0); //clipboard
	char* bufferfileA = "/dev/shm/cpdA.b";
	char* bufferfileB = "/dev/shm/cpdB.b";
	int count = 1;

	
	disp = XOpenDisplay(NULL);
	if (!disp) die("can't open X display\n",NULL);

	root = DefaultRootWindow(disp);

	clip = XInternAtom(disp, "CLIPBOARD", False);

	XFixesSelectSelectionInput(disp, root, clip, XFixesSetSelectionOwnerNotifyMask);
	
	(void)setvbuf(stdout, NULL, _IONBF, 0);
	
	// creo subito i due file buffer, non è fondamentale per il funzionamento dell'algoritmo ma serve maggiormente
	// per interfaccia bash, potrei effettivamente gestire questa cosa da quella parta ma servirebbero controlli e inoltre
	// verrebbero eseguiti comandi, quindi forse è più ottimizzato qui
	fb = fopen(bufferfileA, "w");
	if (fb == NULL) die("error to open file buffer A", strerror(errno));
	if (fclose(fb)) die("error to close file buffer A", strerror(errno));
	fb = fopen(bufferfileB, "w");
	if (fb == NULL) die("error to open file buffer B", strerror(errno));
	if (fclose(fb)) die("error to close file buffer B", strerror(errno));

	fb = NULL;
	
	do {
		
		XNextEvent(disp, &evt); // suppongo che il codice si blocchi qui
		
		char buffer[1024];
		int i, ch;

		// Eseguiamo xclip in modalità lettura (-o)
		// "r" significa che vogliamo LEGGERE l'output del comando
		fp = popen("xclip -o -selection clipboard 2>/dev/null", "r");
		if (fp == NULL) die("error in popen", strerror(errno));
		
		for (i = 0; (i < (sizeof(buffer)-1) && ((ch = fgetc(fp)) != EOF)); i++)
			buffer[i] = ch;
	 
		buffer[i] = '\0';
		if (pclose(fp) == -1) die("errore to close command buffer", strerror(errno));
		  
		if (count == 10){
			fb = fopen(bufferfileB, "w");
			if (fb == NULL) die("error to open file buffer B", strerror(errno));
			if (fclose(fb)) die("error to close file buffer B", strerror(errno));
			fb = fopen(bufferfileA, "ab+");
			if (fb == NULL) die("error to open file buffer A", strerror(errno));
			if(!fprintf(fb, "%s%c", buffer, '\0')) die("error to write file buffer A", strerror(errno));
			count++;
		} else if (count == 20){
			fb = fopen(bufferfileA, "w");
			if (fb == NULL) die("error to open file buffer A", strerror(errno));
			if (fclose(fb)) die("error to close file buffer A", strerror(errno));
			fb = fopen(bufferfileB, "ab+");
			if (fb == NULL) die("error to open file buffer B", strerror(errno));
			if(!fprintf(fb, "%s%c", buffer, '\0')) die("error to write file buffer B", strerror(errno));
			count = 1;
		} else if (count < 10){
			fb = fopen(bufferfileA, "ab+");
			if (fb == NULL) die("error to open file buffer A", strerror(errno));
			if(!fprintf(fb, "%s%c", buffer, '\0')) die("error to write file buffer A", strerror(errno));
			count++;
		} else if (count > 10){
			fb = fopen(bufferfileB, "ab+");
			if (fb == NULL) die("error to open file buffer B", strerror(errno));
			if(!fprintf(fb, "%s%c", buffer, '\0')) die("error to write file buffer B", strerror(errno));
			count++;
		}
		if (fclose(fb)) die("error to close file buffer", strerror(errno));
		

	} while (1);
	
	XCloseDisplay(disp);
	
	return 0;
}




// comando per reload dei servizi di systemctl
// sudo systemctl daemon-reload
 
 // comandi pef monitorare e gestire il servizio
 // systemctl --user start cpd
 // systemctl --user stop cpd
 // systemctl --user status cpd

// comando che dovrebbe mostrare messaggi di errore scritti dal servizio
// journalctl --user -u cpd -p err






