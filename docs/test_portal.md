# Test portal

The online test portal dramatically lowers the bar to testing your design in AWS F1 environment. 

Rather than go through the process of enabling AWS, the F1 environment, etc., you can design, test and tune your multiplier in Vivado and submit it to the portal to make sure the results are what you expect. 

Once you submit your design, the test portal will clone your repo, run simulation, hardware emulation, synthesis/place and route, and provide the results back to you in an encrypted file on S3. 

## Usage limitations

- The portal is not intended for basic testing - you should test and tune your design in Vivado first.
- The script will schedule requests prevent spamming and provide a level of access/fairness to the teams
- There will be a time limit of 8 hours for any request. We'll revise this if needed based on usage data. The goal is to balance allowing jobs to complete with fairness and availability to all teams.

## API

Usage: msu/scripts/portal --access KEY [command]

- --access - secret access key, issued per team. This is a hash of the encryption key.
- command
  - list - display pending jobs
  - cancel JOBID - cancel a job
  - submit repo [options] - submit a repo for processing
    - --sim - run simulations
    - --hw-emu - run hardware emulation
    - --synthesis - run synthesis/pnr
    - --email - notification email address
    - Each stage runs all preceeding stages

## Job flow

1. The API endpoint will validate the request and use the secret key to authorize the transaction.
1. Once the job is scheduled the endpoint will dispatch it to a worker, which may be a long running instance, AWS Batch, or some other mechanism.
1. The worker will instantiate a docker image on a z1d.2xlarge, setup the F1 environment, and run the job. 
1. The worker will gather the results, including log files and reports, create a tarball, and encrypt it with a randomly generated password.
1. The worker will publish the results on a shared S3 node and send an email notification.
