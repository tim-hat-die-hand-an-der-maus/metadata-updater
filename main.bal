import ballerina/http;
import ballerina/io;
import ballerina/os;

type QueueItem record {
    string id;
};

type Queue record {
    QueueItem[] queue;
};

type Cover record {
    string url;
    float ratio;
};

type Imdb record {
    string id;
    string title;
    int year;
    string rating;
    Cover cover;
};

type Movie record {
    string id;
    string status;
    Imdb imdb;
};

type ImdbResolverRequest record {
    string imdbUrl;
};

type MetadataPatchRequest record {
    string[] refresh;
};

function diffRecordFields(Imdb r1, Imdb r2) returns string[] {
    map<anydata> m1 = r1;
    map<anydata> m2 = r2;

    string[] diff = [];
    foreach var k in m1.keys() {
        string key = k;
        if m1[k] != m2[k] {
            if k == "cover" {
                key = "coverUrl";
            }
            diff.push(key);
        }
    }

    return diff;
}

function getMovieById(string id, http:Client apiClient) returns Movie? {
    Movie|error movie = apiClient->get("/movie/" + id);
    if movie is error {
        io:println("error retrieving movie by id: " + id + " due to " + movie.toString());
        return ();
    }

    return movie;
}

function getUrl(string url) returns string|error {
    final http:Client c = check new (url, { timeout: 2 });

    return c->get("/", targetType = string);
}

function updateMovie([Movie, string[]] input) returns json|error {
    var [movie, diffKeys] = input;

    final http:Client c = check new("https://api.timhatdiehandandermaus.consulting");
    MetadataPatchRequest req = { refresh: diffKeys };

    return c->patch("/movie/" + movie.id + "/metadata" , req.toJsonString(), { "Content-Type": "application/json"});
}

function resolveMovieId(string id) returns Imdb|error {
    string url = os:getEnv("IMDB_RESOLVER_URL");
    final http:Client c = check new(url);
    // exploit that the imdb-resolver is using `match = re.search(".*tt(\d+)", req.imdbUrl)`
    ImdbResolverRequest req = { imdbUrl: "https://www.imdb.com/title/tt" + id };

    Imdb|error imdb = check c->post("/", req.toJsonString(), {"Content-Type": "application/json"});

    return imdb;
}

public function main() returns error? {
    final http:Client apiClient = check new ("https://api.timhatdiehandandermaus.consulting", { timeout: 2 });
    Queue queue = check apiClient->get("/queue");
    Movie?[] rawMovies = queue.queue.map(item => getMovieById(item.id, apiClient));
    Movie[] movies = [];
    foreach Movie? movie in rawMovies {
        if movie != () {
            movies.push(movie);
        }
    }

    (string|error)[] thumbnailUrlResults = movies.map(movie => getUrl(movie.imdb.cover.url));
    foreach int i in 0 ..< thumbnailUrlResults.length() {
        if thumbnailUrlResults[i] is error {
            movies[i].imdb.cover.url = "";
        }
    }

    [Movie, string[]][] diff = [];
    foreach Movie m in movies {
        Imdb|error Imdb = resolveMovieId(m.imdb.id);
        if Imdb is error {
            io:println("unable to resolve " + m.imdb.id + " due to " + Imdb.toString());
            continue;
        }

        string[] diffKeys = diffRecordFields(m.imdb, Imdb);
        if diffKeys.length() > 0 {
           diff.push([m, diffKeys]);
        }
    }

    io:println(diff.'map(updateMovie));
}
