Important - need to download jq (https://jqlang.github.io/jq/download/) and Git Bash if running on Windows (https://git-scm.com/download/win)

The script assumes that the executable is called/has been renamed to jq.exe. The original name may have some suffix to denote the architecture
it was compiled for.

Once jq.exe (also in this repo) has been downloaded, move it to its permanent location and add the executable's parent directory
to Path in Windows' environment variables. Once "installed" restart git bash and run ```jq --version```. If the version isn't printed
jq hasn't 

Optionally create a .env file with a key value pair with key set as "machine_name". For logging purposes this will serve as a nickname
to id the source machine

Command to start running tests on host machine:
./run_next.sh -p folder-name

-p: flag to let the script know to grab test list from SERVER2022
folder-name: this is the name of the folder (e.g. casio-1-july-12) to create to upload results and logs from current test run

Location on server2022:
\\192.168.50.73\ForReview\Casio\fx-CG100 emulator\automated-testing