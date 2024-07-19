export class Timer {
    constructor() {
        this.t0 = null;
        this.t1 = null;
        this.timeoutSeconds = 30 * 60;
    }

    start = () => {
        this.t0 = Date.now();
        console.log(this.t0);
    };

    stop = () => {
        this.t1 = Date.now();
    };

    reset = () => {
        this.start();
    };

    elapsedTimeSeconds = () => {
        if (this.t0) {
            return (Date.now() - this.t0) / 1000;
        }
        throw new Error("Start time missing");
    };

    exceedsThreshold = () => {
        return this.elapsedTimeSeconds() > this.timeoutSeconds;
    };
}