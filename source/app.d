import vibe.vibe;
import std.stdio;
import std.algorithm;
import std.array;
import vibe.data.json;

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

    void update(string key, string value)
    {
        json[key] = value;
        store();
    }

    void remove(string key)
    {
        json.remove(key);
        store();
    }

    private void store()
    {
        ubyte[] utf8 = cast(ubyte[]) json.serializeToPrettyJson;
        writeFile("data2.json", utf8);
    }
}

auto webInterface(Database database)
{
    class WebInterface
    {
        void index(HTTPServerResponse response)
        {
            response.writeBody(database.json.serializeToPrettyJson);
        }

        @method(HTTPMethod.GET) @path("*")
        void lookup(HTTPServerRequest request)
        {
            auto to = database.lookup(request.requestPath.toString);
            if (to)
            {
                redirect(to);
            }
        }

        @method(HTTPMethod.POST) @path("*")
        void postUpdate(HTTPServerRequest request)
        {
            auto newUrl = getParameter(request, "url");
            if (newUrl)
            {
                database.update(request.requestPath.toString, newUrl);
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
