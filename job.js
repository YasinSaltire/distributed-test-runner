import { Server22 } from "./server22.js";
import { Timer } from './timer.js';
import { exec } from 'child_process';
import { promisify } from 'util';
import downloadsFolder from 'downloads-folder';
import path from 'path';
import open from 'open';
import os from 'os';

export class Job {
    constructor(test) {
        this.test = test;
        this.OPTIONS = 'stop_on_fail=Screen&annotated_log=true';
        this.MODEL = 'CY811';
        this.DOWNLOADS = downloadsFolder().replace(/\\/g, '/') + '/';
        this.BASE_URL = 'https://paperapi.demo-classpad.net/fx-CG100-test/index.html';
        this.keepLooping = true;
        this.testTitle = path.basename(this.test.replace(/\./g, '_'));
        this.id = this.generateId();
        this.reportFileName = `${this.MODEL}-${this.testTitle}-${this.id}.html`; //"CY811-表示コード×変換フラグの動作確認-2024-07-17T17_27_33.031Z.html";//
        this.logFileName = 'Log-' + this.reportFileName;
        this.fullTestUrl = `${this.BASE_URL}?test=${this.test}&${this.OPTIONS}&report_id=${this.id}`;
        this.srv22 = new Server22();
        this.timer = new Timer();
        this.chokidarScanComplete = false;
        this.downloaded = 0;
        this.started = false;
        this.finished = false;
        this.testFailed = false;
        this.execAsync = promisify(exec);
        this.os = null;
        this.privateIP = null;
    }

    myIP = async () => {
        const osType = os.type();
        this.os = osType;
        let isWindows = osType.includes('Windows') ? true : false;
        let command = "";
        if (isWindows) {
            command = "ipconfig | grep 'IPv4' | awk '{print $NF}'";
        } else {
            command = "ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}'";
        }

        const result = await this.execAsync(command);
        this.privateIP = result.stdout.trim();

        return result.stdout.trim();
    };

    writeLog = async (logLine) => {
        if (!logLine) return;

        await this.srv22.appendLineToFile(logLine, "log.txt");
    };

    testAssessment = async () => {
        const fullPathToReport = path.join(this.DOWNLOADS, this.reportFileName);
        const result = await this.execAsync(`grep -q "FAILED" ${fullPathToReport} && echo failed || echo passed`);
        return result.stdout.trim();
    };

    getElapsedTime = () => {
        return this.timer.elapsedTimeSeconds();
    };

    hasTimedOut = () => {
        return this.timer.exceedsThreshold();
    };

    generateId = () => {
        const date = new Date();
        return date.toISOString().replace(/:/g, '_');
    };

    getFullTestUrl = () => {
        return `${this.BASE_URL}?test=${this.test}&${this.OPTIONS}&report_id=${this.id}`;
    };

    getFullReportFileName = () => {
        return `${this.MODEL}-${this.testTitle}-${this.id}.html`;
    };

    startTesting = async () => {
        console.log("___START___");
        this.timer.start();
        this.started = true;
        try {
            await open(this.fullTestUrl, { background: true });
        } catch (error) {
            console.error(error.message);
        }
        const logStarted = `[${this.privateIP.trim()} ${(new Date()).toISOString()}] Started a test (${this.testTitle})`;
        console.log(logStarted);
        try {
            await this.srv22.logToServer2022(logStarted);
        } catch (error) {
            console.error(error.message);
        }
    };
}
