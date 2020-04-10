import vibe.vibe;
import std.stdio;
import std.algorithm;
import std.array;
import vibe.data.json;

/// Database of all shortened urls
class Database
{
    Json json;

    this()
    {
        auto content = readFileUTF8("data.json");
        json = parseJson!string(content);
    }

    string lookup(string id)
    {
        if (id in json)
        {
            return json[id].get!string;
        }
        else
        {
            return null;
        }
    }

    auto update(string id, string value)
    {
        json[id] = value;
        store();
        return this;
    }

    auto remove(string key)
    {
        if (lookup(key)) {
            json.remove(key);
            store();
        }
        return this;
    }

    private void store()
    {
        ubyte[] utf8 = cast(ubyte[]) json.serializeToPrettyJson;
        writeFile("data.json", utf8);
    }
}

unittest {
    Json j = Json(["field1": Json("foo"), "field2": Json(42), "field3": Json(true)]);
    assert("field1" in j);
    j.remove("field1");
    assert("field1" !in j);
}
auto webInterface(Database database)
{
    class WebInterface
    {
        void index(HTTPServerResponse response)
        {
            response.render!("index.dt", database);
        }

        @method(HTTPMethod.GET) @path("*")
        void lookup(HTTPServerRequest request)
        {
            auto to = database.lookup(request.requestPath.toString[1..$]);
            if (to)
            {
                redirect(to);
            }
        }

        @method(HTTPMethod.DELETE) @path("*")
        void deleteShort(HTTPServerRequest request, HTTPServerResponse response) {
            auto slug = request.requestPath.toString[1..$];
            database.remove(slug);
            response.writeBody("All good");
        }

        @method(HTTPMethod.PUT) @path("*")
        void updateShort(HTTPServerRequest request, HTTPServerResponse response) {
            auto slug = request.requestPath.toString[1..$];
            auto newUrl = getParameter(request, "newUrl");
            database.update(slug, newUrl);
            response.writeBody("All good");
        }

        @method(HTTPMethod.POST) @path("*")
        void createUrl(HTTPServerRequest request)
        {
            writeln("create url");
            auto newUrl = getParameter(request, "url");
            if (newUrl)
            {
                database.update(request.requestPath.toString[1..$], newUrl);
                redirect("/");
            }
            else
            {
                throw new HTTPStatusException(400, "please specify url");
            }
        }

        auto getParameter(HTTPServerRequest request, string key)
        {
            if (key in request.query)
            {
                return request.query[key];
            }
            else if (key in request.json)
            {
                return request.json[key].get!string;
            }
            else
            {
                return null;
            }
        }

        @method(HTTPMethod.DELETE) @path("*")
        void remove(HTTPServerRequest request)
        {
            auto key = request.requestPath.toString;
            if (database.lookup(key))
            {
                database.remove(key);
                redirect("/");
            }
            else
            {
                throw new HTTPStatusException(400, "unknown url");
            }
        }
    }

    return new WebInterface();
}

void main()
{
    auto router = new URLRouter;
    auto database = new Database;

    router.registerWebInterface(webInterface(database));

    auto settings = new HTTPServerSettings;
    settings.port = 4567;
    settings.bindAddresses = ["::1", "127.0.0.1"];
    listenHTTP(settings, router);
    runApplication();
}
