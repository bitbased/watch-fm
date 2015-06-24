window.getUsername = ->
  username = window.localStorage.getItem("lastfm.username")
  username = "" unless username
  return username

window.setUsername = (username) ->
  window.localStorage.setItem("lastfm.username", username)

window.getRawUpdateRate = ->
  rate = window.localStorage.getItem("lastfm.rate")
  rate = 10 unless rate
  return rate

window.getUpdateRate = ->
  rate = window.localStorage.getItem("lastfm.rate")

  if window.getUsername() == ""
    rate = 300
  else
    return 10 unless window.last_duration
    tm = (new Date() - window.last_play) / 1000
    rate = 20
    rate = 10 if tm >= window.last_duration - 45 && tm <= window.last_duration + 45
    rate = 3 if tm >= window.last_duration - 15 && tm <= window.last_duration + 15
    rate = 3 if tm < 15
    rate = 60 if tm > 500 + window.last_duration
    rate = 5 if window.last_duration < 0
  rate = 10 unless rate
  return rate

window.setUpdateRate = (rate) ->
  window.localStorage.setItem("lastfm.rate", rate)

# dithering algorithm adapted from: https://github.com/meemoo/iframework/blob/gh-pages/src/nodes/image-monochrome-worker.js

bayerThresholdMap = [
  [  15, 135,  45, 165 ],
  [ 195,  75, 225, 105 ],
  [  60, 180,  30, 150 ],
  [ 240, 120, 210,  90 ]
]

lumR = []
lumG = []
lumB = []
for i in [0...256] by 1
  lumR[i] = i*0.299
  lumG[i] = i*0.587
  lumB[i] = i*0.114

window.monochrome = (imageData, threshold, type) ->
  imageDataLength = imageData.data.length;

  # Greyscale luminance (sets r pixels to luminance of rgb * alpha)
  for i in [0..imageDataLength] by 4
    imageData.data[i] = Math.floor((lumR[imageData.data[i]] + lumG[imageData.data[i+1]] + lumB[imageData.data[i+2]]) * (imageData.data[i+3]/256))

  w = imageData.width;
  #var newPixel, err;

  for currentPixel in [0..imageDataLength] by 4

    if (type == "none")
      # No dithering
      imageData.data[currentPixel] = if imageData.data[currentPixel] < threshold then 0 else 255;
    else if (type == "bayer")
      # 4x4 Bayer ordered dithering algorithm
      x = currentPixel/4 % w;
      y = Math.floor(currentPixel/4 / w);
      map = Math.floor( (imageData.data[currentPixel] + bayerThresholdMap[x%4][y%4]) / 2 );
      imageData.data[currentPixel] = if (map < threshold) then 0 else 255;
    else if (type == "floydsteinberg")
      # Floyd–Steinberg dithering algorithm
      newPixel = if imageData.data[currentPixel] < 129 then 0 else 255;
      err = Math.floor((imageData.data[currentPixel] - newPixel) / 16);
      imageData.data[currentPixel] = newPixel;

      imageData.data[currentPixel       + 4 ] += err*7;
      imageData.data[currentPixel + 4*w - 4 ] += err*3;
      imageData.data[currentPixel + 4*w     ] += err*5;
      imageData.data[currentPixel + 4*w + 4 ] += err*1;
    else
      # Bill Atkinson's dithering algorithm
      newPixel = if imageData.data[currentPixel] < threshold then 0 else 255;
      err = Math.floor((imageData.data[currentPixel] - newPixel) / 8);
      imageData.data[currentPixel] = newPixel;

      imageData.data[currentPixel       + 4 ] += err;
      imageData.data[currentPixel       + 8 ] += err;
      imageData.data[currentPixel + 4*w - 4 ] += err;
      imageData.data[currentPixel + 4*w     ] += err;
      imageData.data[currentPixel + 4*w + 4 ] += err;
      imageData.data[currentPixel + 8*w     ] += err;

    # Set g and b pixels equal to r
    imageData.data[currentPixel + 1] = imageData.data[currentPixel + 2] = imageData.data[currentPixel]

  return imageData;




window.updateimage = (image_url) ->
  return if !image_url || image_url == ""
  console.log(image_url)
  image = new Image()
  image.onload = () =>
    canvas = document.createElement('canvas')
    size = 160
    display = 144

    fade = Math.floor(display*0.25)
    canvas.width = size
    canvas.height = size

    context = canvas.getContext('2d')
    context.drawImage(image, 0, 0, image.width, image.height, 0, 0, display, display)

    imageData = context.getImageData(0, 0, size, size)

    for f in [0...fade] by 1
      val = Math.floor(180/fade*f)+65
      y2 = f
      y = display - f - 1
      for x in [0...display] by 1
        imageData.data[y*4*size+x*4+3] = val
        imageData.data[y2*4*size+x*4+3] = val

    imageData = window.monochrome(imageData,127,"floydsteinberg")

    window.queue_data = []
    window.queue_waiting = false
    row_data = []
    row_start = 0
    v = 0
    b = 0
    ii = 0
    for row in [0...size] by 1
      b = 0
      for i in [0...size] by 1
        grayscale = imageData.data[ii]
        ii+=4
        row_data[v] = 0 unless row_data[v] > 0 && row_data[v] <= 255
        if grayscale > 128
          row_data[v] += Math.pow(2,b)
        b++
        if b > 7
          v++
          b = 0

      if row_data.length >= 200
        console.log("row:#{row_start} #{row_data.length} bytes")
        window.queue_data.push {row_index: row_start, row_data}

        row_start = (row+1) * (size/8)
        row_data = []
        v = 0
        b = 0

    if row_data.length > 0
      console.log("row:#{row_start} #{row_data.length} bytes")
      window.queue_data.push {row_index: row_start, row_data}

  image.src = image_url


window.updateTrack = (data) ->
  changed = 0
  changed = 1 unless window.last_data == data.currentTrack.artist + data.currentTrack.title
  return unless changed
  console.log("Sending Message: " + data.currentTrack.artist + " - " + data.currentTrack.title)

  window.waiting = true

  Pebble.sendAppMessage {"artist":data.currentTrack.artist.substring(0,40), "title":data.currentTrack.title.substring(0,40), "changed":changed}, ->
    window.last_data = data.currentTrack.artist + data.currentTrack.title
    window.waiting = false
  , -> window.waiting = false

  req = "http://ws.audioscrobbler.com/2.0/?method=track.getinfo&api_key=#{SecretConfig.lastfm_api_key}&mbid=#{data.currentTrack.mbid}&format=json"
  if data.currentTrack.mbid == ""
    req = "http://ws.audioscrobbler.com/2.0/?method=track.getinfo&api_key=#{SecretConfig.lastfm_api_key}&artist=#{data.currentTrack.artist}&track=#{data.currentTrack.title}&format=json"
  console.log req
  $.ajax
    cache: false
    url: req
    success: (response) ->
      image_url = ""
      console.log("LOG:" + image_url)
      if response.track && response.track.album
        for img in response.track.album.image
          if img.size == "large" && (!image_url || image_url == "")
            image_url = img["#text"]
          if img.size == "extralarge" && img["#text"] != ""
            image_url = img["#text"]
      window.last_play = new Date()
      if window.last_duration
        window.last_duration = response.track.duration / 1000
        Pebble.sendAppMessage {"duration": parseInt(response.track.duration / 1000)}, ->
          console.log ("DURATION_SUCCESS")
        , =>
          console.log ("DURATION_TIMEOUT")
          Pebble.sendAppMessage {"duration": parseInt(response.track.duration / 1000)}, ->
            console.log ("DURATION_RETRY_SUCCESS")

      else
        window.last_duration = -(response.track.duration / 1000)
      window.updateimage(image_url)
    error: (e,error) =>
      console.log error
      window.updateimage(data.image_url) unless !data.image_url || data.image_url == ""


mainLoop = ->
  window.interval_count++
  console.log("Rate: #{window.getUpdateRate()}, #{window.interval_count}, #{Math.floor((new Date() - window.last_play) / 1000)}/#{window.last_duration}")
  if window.interval_count == -1
    window.queue_waiting = false
    window.waiting = false
  return if window.interval_count < window.getUpdateRate()
  window.interval_count = -5
  return if window.waiting


  if window.getUsername() == ""
    console.log "http://ws.audioscrobbler.com/2.0/?method=chart.gettoptracks&api_key=#{SecretConfig.lastfm_api_key}&format=json"
    $.ajax
      url: "http://ws.audioscrobbler.com/2.0/?method=chart.gettoptracks&api_key=#{SecretConfig.lastfm_api_key}&format=json"
      cache: false
      timeout: 5000
      success: (data) ->
        window.interval_count = 0
        return unless data.tracks
        r = Math.floor(Math.random()*data.tracks.track.length)
        console.log r
        artist = data.tracks.track[r].artist["name"]
        album = ""
        mbid = data.tracks.track[r].mbid
        title = data.tracks.track[r].name
        image_url = null
        if data.tracks.track[r] && data.tracks.track[r].image
          for img in data.tracks.track[r].image
            if img.size == "large" && (!image_url || image_url == "")
              image_url = img["#text"]
            if img.size == "extralarge" && img["#text"] != ""
              image_url = img["#text"]
        else
          window.interval_count = window.getUpdateRate() - 10
        console.log(artist + " - " + title + " - " + image_url)
        window.updateTrack({currentTrack: {artist, album, title, image_url, mbid } })
      error: (err,error,text) ->
        window.interval_count = 0
        console.log error
  else
    console.log "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=#{window.getUsername()}&limit=1&api_key=#{SecretConfig.lastfm_api_key}&format=json"
    $.ajax
      url: "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=#{window.getUsername()}&limit=1&api_key=#{SecretConfig.lastfm_api_key}&format=json"
      cache: false
      timeout: 5000
      success: (data) ->
        window.interval_count = 0
        return unless data.recenttracks
        track = data.recenttracks.track[0]
        track = data.recenttracks.track if track == undefined
        artist = track.artist["#text"]
        album = track.album["#text"]
        mbid = track.mbid
        title = track.name
        image_url = null
        if track
          for img in track.image
            if img.size == "large" && !image_url
              image_url = img["#text"]
            if img.size == "extralarge"
              image_url = img["#text"]
        console.log(artist + " - " + title + " - " + image_url + " ! " + mbid)
        window.updateTrack({currentTrack: {artist, album, title, image_url, mbid} })
      error: (err,error,text) ->
        window.interval_count = 0
        console.log error

window.queue_data = []
window.queue_waiting = false

queue = ->
  unless window.queue_waiting
    if window.queue_data.length > 0
      window.queue_waiting = true
      data = window.queue_data[0]
      console.log("TRY row:#{data.row_index} #{data.row_data.length} bytes")
      Pebble.sendAppMessage data, =>
        if window.queue_data[0] && window.queue_data[0].row_index == data.row_index
          console.log("SENT row:#{data.row_index} #{data.row_data.length} bytes")
          window.queue_data.shift()
        else
          console.log("SENT?? row:#{data.row_index} #{data.row_data.length} bytes")
        window.queue_waiting = false
      , -> window.queue_waiting = false


Pebble.addEventListener "webviewclosed", (e) ->
  data = JSON.parse(e.response)
  window.setUsername(data.lastfm_username)
  window.interval_count == window.getUpdateRate() - 1;

Pebble.addEventListener "showConfiguration", (e) ->
  page = """<html>
  <head>
    <script>
      function submit()
      {
        data = { lastfm_username: document.getElementById('lastfm_username').value };
        window.location.href='pebblejs://close#' + encodeURIComponent(JSON.stringify(data));
      }
    </script>
  </head>
  <body>
    <h1>Last.fm account</h1>
    Username: <input type="text" id="lastfm_username" value="#{window.getUsername()}">
    <br>
    <button onClick="submit()" value="Save">
      Save
    </button>
  </body>
  </html>"""
  Pebble.openURL("data:text/html;charset=utf-8,"+encodeURIComponent(page)+"<!--.html")

Pebble.addEventListener "ready", (e) ->
  console.log("JavaScript app ready and running!")
  window.interval_count = window.getUpdateRate() - 5;
  mainLoop()
  setInterval(mainLoop, 1000)
  setInterval(queue,80)

Pebble.addEventListener "appmessage", (e)->
  console.log("Received message: " + e.payload.action)
