napodobuje solax invertor api: při každém volání dává zpět odpověd jako solax X G4....
ale data si bere ze souboru data.json: vždy každý další řádek a tak pořád dokola...



# build
docker build -t solax-sim:latest .

# run (publikuje port 8081 na hostu)
docker run -d --name solax-sim -p 8081:80 solax-sim:latest

# remove 
docker stop solax-sim

# remove 
docker rm solax-sim


# rebuild
cd solax_mockup && \
docker stop solax-sim && docker rm solax-sim && docker run -d --name solax-sim -p 8081:80 solax-sim:latest && docker run -d --name solax-sim -p 8081:80 solax-sim:latest && \
cd ..
