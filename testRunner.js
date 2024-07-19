import { Job } from "./job.js";
import { Server22 } from "./server22.js";
import { exec } from 'child_process';
import { promisify } from 'util';
import chokidar from 'chokidar';
import downloadsFolder from 'downloads-folder';
import path from 'path';
import os from 'os';

const execAsync = promisify(exec);
const osType = os.type();

async function getPrivateIP() {
    let isWindows = osType.includes('Windows') ? true : false;
    let command = "";
    if (isWindows) {
        command = "ipconfig | grep 'IPv4' | awk '{print $NF}'";
    } else {
        command = "ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}'";
    }
    const result = await execAsync(command);
    return result.stdout.trim();
}

let IP = null;

try {
    IP = await getPrivateIP();
} catch (error) {
    console.error(error.message);
}

const DEFAULT_SERVER20222_DIR = "//192.168.50.73/ForReview/automated-testing/";

const srv22 = new Server22();
const downloads = downloadsFolder().replace(/\\/g, '/');
let chokidarScanComplete = false;
const jobs = [];
async function testAssessment(fileName) {
    const fullPathToReport = path.join(downloads, fileName);
    try {
        const result = await execAsync(`grep -q "FAILED" ${fullPathToReport} && echo failed || echo passed`);
        return result.stdout.trim();
    } catch (error) {
        console.error(error.message);
    }
}

async function hasFailed(fileName) {
    const assessment = await testAssessment(fileName);
    return assessment === "failed";
}

async function fileExists(file) {
    let result = await execAsync(`[ -f ${file} ] && echo yes || echo no`);
    console.log(result);
    return result.stdout.trim() === "yes";
}

const watcher = chokidar.watch(downloads + '/', { persistent: true });
watcher.on('ready', () => {
    chokidarScanComplete = true;
    console.log("- Chokidar has finished scanning the downloads folder");
});
// srv22.sendFile(this.DOWNLOADS + this.logFileName, "passed");

watcher.on('add', async (filePath) => {
    if (!chokidarScanComplete) return;

    console.log("*** New file added ***");
    const fileName = path.basename(filePath);
    const fullPathToFile = path.join(downloads, fileName);
    const isReport = !fileName.startsWith("Log-");
    const companionFileName = isReport ? "Log-" + fileName : fileName.slice(4);
    const companionFullPath = path.join(downloads, companionFileName);
    let log = null;
    let report = null;

    // files will only be uploaded to server2022 if both report and log are found
    if (await fileExists(fullPathToFile) && await fileExists(companionFullPath)) {
        if (fullPathToFile.startsWith("Log-")) {
            log = fullPathToFile;
            report = companionFullPath;
        } else {
            log = companionFullPath;
            report = fullPathToFile;
        }
        const failed = await hasFailed(report);
        let destination = failed ? "failed" : "passed";
        console.log("copying to srv2022");
        await srv22.sendFile(log, destination);
        await srv22.sendFile(report, destination);
        const log1 = `[${IP} ${(new Date()).toISOString()}] ${log} uploaded to Server2022`;
        const log2 = `[${IP} ${(new Date()).toISOString()}] ${report} uploaded to Server2022`;
        await srv22.logToServer2022(log1);
        await srv22.logToServer2022(log2);
    }
});

let keepLooping = true;
let startNewTest = true;

let line = null;
let job = null;
let masterListEmpty = false;
while (keepLooping) {

    if (startNewTest) {
        try {
            line = await srv22.getLastLine();

            if (line.length === 0) {
                keepLooping = false;
                masterListEmpty = true;
                console.log("nothing more to do");
            }

            await srv22.deleteLastLine();
            job = new Job(line.trim());
            job.os = osType;
            job.privateIP = IP;

            if (masterListEmpty) {
                const logListEmpty = `[${job.privateIP} ${(new Date()).toISOString()}] Master list is empty`;
                await srv22.logToServer2022(logListEmpty);
                break;
            }

            const logFetchedLine = `[${job.privateIP} ${(new Date()).toISOString()}] Fetched ${job.testTitle} and removed it from master list`;
            await srv22.logToServer2022(logFetchedLine);
            await job.startTesting();
            jobs.push(job);
            startNewTest = false;
        } catch (error) {
            console.error(error.message);
        }
    }

    const jobHasFinished = job.finished;
    const timedOut = job.hasTimedOut();
    // if job has finished or job has been going 
    // for > 30m and it has not finished
    // start a new job
    // send test to retry list (yet to be implemented)
    if (jobHasFinished || timedOut) {
        startNewTest = true;
    }

    if (jobHasFinished) {
        const logFinished = `[${job.privateIP} ${(new Date()).toISOString()}] A test (${job.testTitle}) has finished`;
        await srv22.logToServer2022(logFinished);
    }

    if (timedOut) {
        // write to timed-out.txt
        const logTimedOut = `[${job.privateIP} ${(new Date()).toISOString()}] (${job.testTitle}) may have timed out`;
        await srv22.writeLog(logTimedOut);
        // ones in timed-out.txt will need to be run again with different setting
        await job.srv22.appendLineToFile(line, "timed-out.txt");
    }
}

console.log("exited loop");