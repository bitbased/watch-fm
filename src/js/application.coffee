isColorDisplay = false
if (Pebble.getActiveWatchInfo)
  isColorDisplay = Pebble.getActiveWatchInfo().platform != "aplite"

window.isColorDisplay = isColorDisplay
lastUrl = ""

window.getDisplayMode = ->
  display_mode = window.localStorage.getItem("display_mode")
  display_mode = (if isColorDisplay then "color_dithered" else "monochrome_dithered") unless display_mode
  return display_mode

window.setDisplayMode = (display_mode) ->
  if (window.getDisplayMode() != display_mode)
    setTimeout =>
      window.updateimage(lastUrl)
    , 250
  window.localStorage.setItem("display_mode", display_mode)

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

window.dither = (imageData, threshold, type, grayscale) ->
  imageDataLength = imageData.data.length;

  # default grayscale to true
  if (typeof grayscale == "undefined")
    grayscale = true

  if (grayscale)
    # Grayscale luminance (sets r pixels to luminance of rgb * alpha)
    for i in [0..imageDataLength] by 4
      imageData.data[i] = Math.floor((lumR[imageData.data[i]] + lumG[imageData.data[i+1]] + lumB[imageData.data[i+2]]) * (imageData.data[i+3]/256))
  else
    # Applies alpha value to image colors
    for i in [0..imageDataLength] by 4
      imageData.data[i] = Math.floor(imageData.data[i] * (imageData.data[i+3]/256))
      imageData.data[i+1] = Math.floor(imageData.data[i+1] * (imageData.data[i+3]/256))
      imageData.data[i+2] = Math.floor(imageData.data[i+2] * (imageData.data[i+3]/256))

  w = imageData.width;

  step = 4
  if (!grayscale)
    step = 1

  for currentPixel in [0..imageDataLength] by step

    if (type == "none")
      # No dithering
      if grayscale
        imageData.data[currentPixel] = if imageData.data[currentPixel] < threshold then 0 else 255;
    else if (type == "bayer")
      # 4x4 Bayer ordered dithering algorithm
      x = currentPixel/4 % w;
      y = Math.floor(currentPixel/4 / w);
      map = Math.floor( (imageData.data[currentPixel] + bayerThresholdMap[x%4][y%4]) / 2 );
      imageData.data[currentPixel] = if (map < threshold) then 0 else 255;
    else if (type == "floydsteinberg")
      # Floyd–Steinberg dithering algorithm

      #newPixel = if imageData.data[currentPixel] < threshold then 0 else 255;
      newPixel = Math.floor(Math.round(imageData.data[currentPixel]/64)*64)

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

    if (grayscale)
      # Set g and b pixels equal to r
      imageData.data[currentPixel + 1] = imageData.data[currentPixel + 2] = imageData.data[currentPixel]
      imageData.data[currentPixel + 3] = 255
    else
      if (currentPixel % 4 == 3)
        imageData.data[currentPixel] = 255

  return imageData;

window.updateimage = (image_url) ->
  return if !image_url || image_url == ""
  lastUrl = image_url
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

    switch window.getDisplayMode()
      when "color_dithered"
        imageData = window.dither(imageData, 127, "floydsteinberg", false)
      when "color"
        imageData = window.dither(imageData, 127, "none", false)
      when "grayscale_dithered"
        imageData = window.dither(imageData, 127, "floydsteinberg", true)
      when "monochrome_dithered"
        imageData = window.dither(imageData, 127, "floydsteinberg", true)
        imageData = window.dither(imageData, 127, "none", true)
      when "monochrome"
        imageData = window.dither(imageData, 127, "none", true)
      else
        if isColorDisplay
          imageData = window.dither(imageData, 127, "floydsteinberg", false)
        else
          imageData = window.dither(imageData, 127, "floydsteinberg", true)
          imageData = window.dither(imageData, 127, "none", true)


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

        if isColorDisplay
          _r = Math.floor(imageData.data[ii+0] / 256 * 4)
          _g = Math.floor(imageData.data[ii+1] / 256 * 4)
          _b = Math.floor(imageData.data[ii+2] / 256 * 4)
          _a = 4

          row_data.push(_b + _g*2*2 + _r*2*2*2*2 + _a*2*2*2*2*2*2)
          v++
        else
          grayscale = imageData.data[ii]
          row_data[v] = 0 unless row_data[v] > 0 && row_data[v] <= 255
          if grayscale > 128
            row_data[v] += Math.pow(2, b)
          b++
          if b > 7
            v++
            b = 0
        ii += 4

      if (isColorDisplay && row_data.length >= size * 3 - 1) || (!isColorDisplay && row_data.length >= 200)
        #console.log("row:#{row_start} #{row_data.length} bytes")
        window.queue_data.push {row_index: row_start, row_data}
        if isColorDisplay
          row_start = (row + 1) * (size)
        else
          row_start = (row + 1) * (size / 8)
        row_data = []
        v = 0
        b = 0

    if row_data.length > 0
      #console.log("row:#{row_start} #{row_data.length} bytes")
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
  console.log req.replace(SecretConfig.lastfm_api_key, "HIDDEN_API_KEY")
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
      #console.log("TRY row:#{data.row_index} #{data.row_data.length} bytes")
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
  window.setDisplayMode(data.display_mode)
  window.interval_count == window.getUpdateRate() - 1;

Pebble.addEventListener "showConfiguration", (e) ->
  page = """<html>
  <head>
    <script>
      function submit()
      {
        var e = document.getElementById("display_mode");
        var display_mode = e.options[e.selectedIndex].value;

        data = { lastfm_username: document.getElementById('lastfm_username').value, display_mode: display_mode };
        window.location.href='pebblejs://close#' + encodeURIComponent(JSON.stringify(data));
      }
    </script>
    <style>
      h1 {
        background-color: #eeeeee;
        border-bottom: 1px solid #dddddd;
        padding: 0.2em;
        text-align: center;
      }
      h3 {
        margin-bottom: 0px;
      }
      body, #lastfm_username, #display_mode {
        line-height: 1.5;
        padding: 0px;
        margin: 0px;
      }
      .main-form {
        font-size: 1.5em;
        line-height: 1.5;
        text-align: center;
      }
      button, select, input {
        font-size: 1.2em;
        padding: 0.2em 0.8em;
      }
      input {
          width: 80%;
      }
    </style>
  </head>
  <body>
    <h1>Watch.fm Settings</h1>
    <div class="main-form">

    <h3>last.fm Username</h3>
    <input type="text" id="lastfm_username" value="#{window.getUsername()}">
    <hr>

    <h3>Display Mode</h3>
    <select id="display_mode">
      <option #{if !window.isColorDisplay then 'style="display:none"'} value="color_dithered" #{ if window.getDisplayMode() == "color_dithered" then 'selected="selected"' }>Color Dithered</option>
      <option #{if !window.isColorDisplay then 'style="display:none"'} value="color" #{ if window.getDisplayMode() == "color" then 'selected="selected"' }>Color</option>
      <option #{if !window.isColorDisplay then 'style="display:none"'} value="grayscale_dithered" #{ if window.getDisplayMode() == "grayscale_dithered" then 'selected="selected"' }>Grayscale</option>
      <option value="monochrome_dithered" #{ if window.getDisplayMode() == "monochrome_dithered" then 'selected="selected"' }>Monochrome Dithered</option>
      <option value="monochrome" #{ if window.getDisplayMode() == "monochrome" then 'selected="selected"' }>Monochrome</option>
    </select>
    <hr>
    <button onClick="submit()" value="Save">
      Save
    </button>
    </div>
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
