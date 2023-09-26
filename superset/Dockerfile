FROM apache/superset
ENV SUPERSET_SECRET_KEY=your_secret_key_here
USER root
RUN pip install pymssql
USER superset
RUN superset fab create-admin --username admin --firstname Superset \
  --lastname Admin --email admin@example.com --password admin
RUN superset db upgrade
RUN superset init