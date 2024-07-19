import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';
// import downloadsFolder from 'downloads-folder';

// const command = 'cd //192.168.50.73 && ls';

// const copyFile = "cp graph.txt //192.168.50.73/ForReview/automated-testing/";

const DEFAULT_SERVER20222_DIR = "//192.168.50.73/ForReview/automated-testing/";

const GIT_BASH_PATH = "C:\\Program Files\\Git\\bin\\bash.exe";

export class Server22 {
    constructor(dir = false, shell = false) {
        this.directory = dir || DEFAULT_SERVER20222_DIR;
        this.passedFolder = this.directory + "passed/";
        this.failedFolder = this.directory + "failed/";
        this.shell = shell || GIT_BASH_PATH;
        this.options = {
            shell: this.shell
        };
        this.execAsync = promisify(exec);
    }

    exec = async (command) => {
        let result = null;
        try {
            result = await this.execAsync(command);

        } catch (error) {
            console.error(error.message);
        }
        return result;
    };

    sendFile = async (file, destination = "home") => {
        let moveTo = "";
        if (destination === "home") {
            moveTo = this.directory;
        } else if (destination === "passed") {
            moveTo = this.passedFolder;
        } else if (destination === "failed") {
            moveTo = this.failedFolder;
        } else {
            console.log("Unrecognized destination flag");
            moveTo = this.directory;
        }
        const command = `cp ${file} ${moveTo}`;
        try {
            await this.exec(command);
        } catch (error) {
            console.error(error.message);
        }

    };

    getLastLine = async (file = "all-tests.txt") => {
        const command = `tail -n 1 ${this.directory}${file}`;
        let result;
        try {
            const { stdout } = await this.exec(command);
            result = stdout;
        } catch (error) {
            console.error(error.message);
        }

        return result;
    };

    deleteLastLine = async (file = "all-tests.txt") => {
        const command = `sed -i '$d' ${this.directory}${file}`;
        try {
            const { stdout } = await this.exec(command);
        } catch (error) {
            console.error(error.message);
        }

        return true;
    };

    appendLineToFile = async (line, fileRelativeToDirectory) => {
        if (line.length < 4) {
            console.error("Provided line is of insufficient length");
            return 0;
        }

        const filePath = path.join(this.directory, fileRelativeToDirectory);

        // const command = `echo "${line}" >> ${this.directory}${fileRelativeToDirectory}`; 

        try {
            fs.appendFile(filePath, line + '\n', { encoding: 'utf8' }, (err) => {
                if (err) {
                    console.error("Error writing to file:", err.message);
                } else {
                    console.log("Line appended successfully.");
                    return 1;
                }
            });
        } catch (error) {
            console.error(error.message);
        }
    };

    logToServer2022 = async (stringToLog) => {
        try {
            await this.appendLineToFile(stringToLog.trim(), "log.txt");
        } catch (error) {
            console.error(error.message);
        }
    };
}