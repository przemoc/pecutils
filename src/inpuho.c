/*
 *  inpuho  --  input hole  for all your weird needs
 *
 * Copyright (c) 2014 Przemyslaw Pawelczyk <przemoc@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject
 * to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#include <signal.h>
#include <stdio.h>
#include <termios.h>
#include <unistd.h>

#define BUFSIZE 4096

#define UNUSED(x) (void)(x)


/* Globals shared with signal handlers */
volatile sig_atomic_t istty = 0;
volatile sig_atomic_t terminated = 0;

/* Forward declarations */
static void input_hole(int signo);
static void input_knit(int signo);


int main()
{
	char buf[BUFSIZE];
	struct sigaction sact = { .sa_flags = SA_RESTART, };
	sigset_t sset;
	ssize_t r;

	/* We don't want any keyboard interruptions. */
	sact.sa_handler = SIG_IGN;
	sigaction(SIGINT,  &sact, NULL);
	sigaction(SIGQUIT, &sact, NULL);
	sigaction(SIGTSTP, &sact, NULL);

	/* We have to detect whether stdin is from terminal. */
	istty = isatty(STDIN_FILENO);

	/* We won't write anything on given stdout. */
	close(STDOUT_FILENO);

	/* Block signals that we'll get our own handler. */
	sigemptyset(&sset);
	sigaddset(&sset, SIGCONT);
	sigaddset(&sset, SIGTERM);
	sigprocmask(SIG_BLOCK, &sset, NULL);

	/* We don't want more than one signal handler at time. */
	sact.sa_mask = sset;
	sact.sa_flags |= SA_NODEFER;

	/* "Show must go on!" */
	sact.sa_handler = input_hole;
	sigaction(SIGCONT, &sact, NULL);

	/* Until we'll hear "This is the end", that is. */
	sact.sa_handler = input_knit;
	sigaction(SIGTERM, &sact, NULL);

	/* All is set up, unblock signals. */
	sigprocmask(SIG_UNBLOCK, &sset, NULL);

	/* Let's drive "Highway to Hell!" */
	input_hole(0);

	/* Starveling emerges. */
	for (;;) {
		r = read(STDIN_FILENO, buf, BUFSIZE);
		if (r <= 0) {
			if (terminated)
				dprintf(STDERR_FILENO, "inpuho: Terminated\n");
			else if (r)
				perror("inpuho: read");
			break;
		}
	}

	/* "Hey, girl, stop what you're doin'!" */
	input_knit(0);

	return 0;
}


/*
 * Local mode flag constants related to terminal interface that we change:
 * - ECHO   - Echo input characters.
 * - ICANON - Enable canonical mode, i.e.
 *   * Input is made available line by line.
 *   * Line editing is enabled.
 * Read termios man page for details.
 */


static void input_hole(int signo)
{
	UNUSED(signo);
	struct termios tios;

	if (istty) {
		tcgetattr(STDIN_FILENO, &tios);
		tios.c_lflag &= ~(ICANON | ECHO);
		tcsetattr(STDIN_FILENO, TCSANOW, &tios);
	}
}


static void input_knit(int signo)
{
	struct termios tios;

	if (istty) {
		tcgetattr(STDIN_FILENO, &tios);
		tios.c_lflag |= ICANON | ECHO;
		tcsetattr(STDIN_FILENO, TCSANOW, &tios);
	}

	if (signo == SIGTERM) {
		terminated = 1;
		close(STDIN_FILENO);
	}
}
