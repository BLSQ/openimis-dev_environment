# Superset

Superset is data exploration and visualization tool.

## Usage

The following requires that you have an up and running OpenIMIS database
and backend. Please follow the instructions in the [main README](../README.md).

Here a quick walktrough to run superset aside OpenIMIS (considering that
openimis-dev is already set up for mssql db and the database prepared):

```bash
./run.sh enable frontend
./run.sh enable superset
./run.sh server
```

Once done, you can go to your browser and visit Superset at
[its local address](http://localhost:8888).

You can login with the username `Admin` and password `admin`.

We have an archive with a datasource, a few datasets and charts, and a dashboard
ready for OpenIMIS. However, this has to be imported manually for the moment
(due to a bug in the [Superset CLI bug](https://github.com/apache/superset/issues/17049)).

Once logged in,

* go to the [dashboard screen](http://localhost:8888/dashboard/list/).
* click on the import button, just at the right of the button `+ DASHBOARD`
* select the file `dashboard_export_20230913T132950.zip` provided in this repo
* click on the `IMPORT` button
* visit the dasboard by clicking on the one named `OpenIMIS` in the list

You should see a dashboard with 3 pie charts:

* Insuree per district
* active policies per district
* Claims per status

![screenshot of the OpenIMIS Superset dashboard]("Screenshot 2023-09-14 at 12-08-25 OpenIMIS.png")

You can filter them by Gender by selecting a gender in the left pane, and/or
by district by clicking on one of the district displayed in one of the pie
charts.

Each dashboard has an "embeddable" version that you can get by adding the
URI query `?standalone=True` to the path of the dashboard. If OpenIMIS dashboard
is the dashboard 1, it would be `http://localhost:8888/superset/dashboard/1/?standalone=True`.

Ideally, it is required to be logged in, and by doing so the create a user
that has a role allowing them to get dashboard in read-only mode. There is a
[way](https://superset.apache.org/docs/security/#public) to display dashboards
without authentication, but this is not recommended in production.

React seems to provide ways to embed directly a dashboard in an app (see for
instance
["Publish superset dashboard on React/NextJS apps"](https://blog.robertoconterosito.it/posts/publish-superset-dashboard-on-react-nextjs-apps/))
or [Embedding Superset dashboards in your React application](https://medium.com/@khushbu.adav/embedding-superset-dashboards-in-your-react-application-7f282e3dbd88)). This
hasn't been tested and probably needs more investigation.

