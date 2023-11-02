# Fume Server

Note to Future Self: I kinda tried to make this as good as possible coding `syntactically` :)

## Intro

Fume Server for hosting numerous of functions. Currently it's only service it runs is `GroupByCity`.

## Navigation

I thought I would write up how to navigate and use this in the future so I wouldn't rewrite this again:

 - Start in the (start.swift)[https://github.com/Awesomeplayer165/Fume-Server-Swift/blob/d4d0f7121d1e3e9f21838a016889ea67d4304d34/Fume-Swift-Server/Fume-Swift-Server/start.swift]. This is where the Server object is defined and services are automatically run.
 - Each service conforms to the `Service` protocol, which defines task states and invoke functions as well as standard constructors, all of which should be overriden.
Then
 - Using Xcode's macOS Terminal template, which I hope can be deployed on some Linux-flavored VPS

## Group By City

1. Gets cache files. By here, shared instance of `FileHelper` should be called and the 
2. Gets Purple Air sensors and filters out unnecessary items like indoor items (NEED TO ADD: sensors not geocoded yet or changed/deleted/added)
3. for every sensor:
   - Write every 10th iteration using `FileHelper` abstraction
   - get boundary dictionary `values` and check if current sensor is in boundary
     - if it is: add it
   - else: // unknown boundary!
      - Reverse GeoCode Sensor to get administrative placeid
      - Get Boundary using placeid
      - Add to dictionaries
4. When finished, returns the task state

## File Helper

Abstraction for FileManager with the focus of improving and generically but easily writing/reading/deleting pre-define files. Everything should be self-explanatory in there since I took the time to write some comments :)


