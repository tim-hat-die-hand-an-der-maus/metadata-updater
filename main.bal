import ballerina/http;
import ballerina/io;

type QueueItem record {
    string id;
};

type Queue record {
    QueueItem[] queue;
};

type Imdb record {
    string id;
    string title;
    int year;
    string rating;
    string coverUrl;
};

type Movie record {
    string id;
    string status;
    Imdb imdb;
};

type ImdbMovie record {
    string id;
    string title;
    int year;
    string rating;
    string coverUrl;
};

function getMovieById(string id, http:Client apiClient) returns Movie? {
    Movie|error movie = apiClient->get("/movie/" + id);
    if movie is error {
        io:println("error retrieving movie by id: " + id);
        return ();
    }

    return movie;
}

function getUrl(string url) returns string|error {
    final http:Client c = check new (url);

    return c->get("/", targetType = string);
}

function updateMovie(Movie movie) returns error? {
    // TODO: see https://github.com/tim-hat-die-hand-an-der-maus/api/issues/31
}

public function main() returns error? {
    final http:Client apiClient = check new ("https://api.timhatdiehandandermaus.consulting");
    Queue queue = check apiClient->get("/queue");
    Movie?[] rawMovies = queue.queue.map(item => getMovieById(item.id, apiClient));
    Movie[] movies = [];
    foreach Movie? movie in rawMovies {
        if movie != () {
            movies.push(movie);
        }
    }
    
    (string|error)[] thumbnailUrlResults = movies.map(movie => getUrl(movie.imdb.coverUrl));
    Movie[] missingThumbnailUrls = [];
    foreach int i in 0 ..< thumbnailUrlResults.length() {
        if thumbnailUrlResults[i] is error {
            missingThumbnailUrls.push(movies[i]);
        }
    }

    _ = missingThumbnailUrls.'map(updateMovie);
}
