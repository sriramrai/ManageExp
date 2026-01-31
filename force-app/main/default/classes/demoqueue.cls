public with sharing class demoqueue implements Queueable {
    public Integer counter;
    public static Integer MAX_LIMIT = 5;

    // Constructor: always initialize counter
    public demoqueue(Integer counter) {
        this.counter = counter;
    }

    public void execute(QueueableContext qc) {
        // Print current counter
        System.debug('Executing Queueable, counter = ' + counter);

        // Safe stop condition
        if(counter < MAX_LIMIT) {
            // Enqueue next Queueable with counter + 1
            System.enqueueJob(new demoqueue(counter + 1));
        } else {
            System.debug('Reached MAX_LIMIT, stopping chain.');
        }
    }
}
