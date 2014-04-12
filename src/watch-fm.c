#include <pebble.h>

#define IMAGE_SIZE 160
#define DISPLAY_SIZE 144

//#define IMAGE_SIZE 64
//#define DISPLAY_SIZE 64

static Window *window;
static TextLayer *text_layer;
static TextLayer *text_layer2;
static TextLayer *text_layer3;
static TextLayer *text_layer4;

static TextLayer *artist_text_layer;
static TextLayer *title_text_layer;
static BitmapLayer *album_art_layer;
static InverterLayer *progress_layer;
//static GBitmap *album_art_bitmap;
static uint8_t album_art_data[IMAGE_SIZE*IMAGE_SIZE/8] = {0};

// Timers can be canceled with `app_timer_cancel()`
static AppTimer *timer;
static bool visible;

static const GBitmap album_art_bitmap = {
  .addr = album_art_data,
  .row_size_bytes = (IMAGE_SIZE / 8),
  .info_flags = 0x1000,
  .bounds = {
    .origin = { .x = 0, .y = 0 },
    .size = { .w = IMAGE_SIZE, .h = IMAGE_SIZE },
  },
};

#define KEY_ACTION 1
#define KEY_STATUS 5
#define KEY_ARTIST 3
#define KEY_TITLE 2
#define KEY_VOLUME 6
#define KEY_CHANGED 7
#define KEY_DURATION 10
#define IMAGE_INDEX 8
#define IMAGE_DATA 9

static int timer_left = 0;
static bool fade_state = true;
static void timer_callback(void *context) {
  const uint32_t timeout_ms = 250;
  if (timer_left > 0) {
    timer_left -= timeout_ms;
    fade_state = !fade_state;
    timer = app_timer_register(timeout_ms, timer_callback, NULL);
  }else{
    fade_state = false;
  }
  layer_set_hidden((Layer*)text_layer2,fade_state);
  layer_set_hidden((Layer*)text_layer3,fade_state);
  layer_set_hidden((Layer*)text_layer4,fade_state);
  layer_set_hidden((Layer*)text_layer,fade_state);
}

static void start_fade_timer(int duration)
{
  fade_state = true;
  timer_left = duration;
  timer_callback(NULL);
}


static void out_sent_handler(DictionaryIterator *sent, void *context) {
  // outgoing message was delivered
}


static void out_failed_handler(DictionaryIterator *failed, AppMessageResult reason, void *context) {
  // outgoing message failed
}


const char track_title[64];
const char track_artist[64];

static int duration = 0;
static int elapsed = 0;
static void update_progress()
{
  int tm = 0;
  if(duration)
  {
    tm = ((double)144.0 / (double)duration)*(double)elapsed;
    if (elapsed < duration + 60)
      elapsed++;
    else
      tm = 0;
  }
  layer_set_frame(inverter_layer_get_layer(progress_layer), GRect(0,167-2,tm,2));
}

static void display_time(struct tm *tick_time) {
  static char timeText[] = "00:00"; // Needs to be static because it's used by the system later.

  time_t now = time(NULL);
  struct tm * currentTime = localtime(&now);

  strftime(timeText, sizeof(timeText), "%l:%M", currentTime);

  text_layer_set_text(text_layer, timeText);
  text_layer_set_text(text_layer2, timeText);
  text_layer_set_text(text_layer3, timeText);
  text_layer_set_text(text_layer4, timeText);
}

static void handle_minute_tick(struct tm *tick_time, TimeUnits units_changed) {
  display_time(tick_time);
}


static void handle_second_tick(struct tm *tick_time, TimeUnits units_changed) {
  update_progress();
}


static void in_received_handler(DictionaryIterator *received, void *context) {
  // incoming message received

  Tuple *value;
  //value = dict_read_first(received);
  value = dict_find(received, KEY_ARTIST);
  if (!!value && value->key == KEY_ARTIST)
  {
    strcpy((char*)track_artist, (char*)value->value);
    persist_write_string(97, (char*)value->value);
    text_layer_set_text(artist_text_layer, track_artist);
  }

  //Tuple *value2;
  value = dict_find(received, KEY_TITLE);
  if (!!value && value->key == KEY_TITLE)
  {
    strcpy((char*)track_title, (char*)value->value);
    persist_write_string(98, (char*)value->value);
    text_layer_set_text(title_text_layer, track_title);
    duration = 0;
    elapsed = 0;
  }

  //Tuple *value3;
  value = dict_find(received, KEY_CHANGED);
  if (!!value && value->key == KEY_CHANGED && value->value->uint32 == 1)
  {
    //light_enable_interaction();
  }

  value = dict_find(received, KEY_DURATION);
  if (!!value && value->key == KEY_DURATION)
  {
    duration = value->value->uint32;
  }

  //Tuple *value3;
  value = dict_find(received, IMAGE_INDEX);
  if (!!value && value->key == IMAGE_INDEX)
  {
    uint32_t i_start = value->value->uint32;
    //Tuple *value3;
    value = dict_find(received, IMAGE_DATA);
    if (!!value && value->key == IMAGE_DATA)
    {
      if (i_start == 0) persist_write_int(99, value->length);

      uint8_t byte_array[256];
      for(uint32_t i = 0; i < value->length; i++)
      {
        album_art_data[i_start+i] = (uint8_t)value->value->data[i];
        byte_array[i] = (uint8_t)value->value->data[i];
      }
      int l = persist_write_data(i_start+100, byte_array, value->length);
      //app_log(APP_LOG_LEVEL_INFO,"",1, "WRITE! row:%i %i bytes of %i", (int)i_start, l, (int)value->length);

      //layer_mark_dirty((Layer*)album_art_layer);
      //light_enable_interaction();
      if (value->length+i_start>=IMAGE_SIZE*IMAGE_SIZE/8)
      {
        start_fade_timer(5000);
        layer_mark_dirty((Layer*)album_art_layer);
        //vibes_short_pulse();
        //light_enable_interaction();
      }
    }

  }
}

static void in_dropped_handler(AppMessageResult reason, void *context) {
  // incoming message dropped
}



static void accel_tap_handler(AccelAxisType axis, int32_t direction) {
  //text_layer_set_text(text_layer, "tap");
}


static void select_click_handler(ClickRecognizerRef recognizer, void *context) {
  DictionaryIterator *iter;
  app_message_outbox_begin(&iter);

  Tuplet value = TupletCString(KEY_ACTION, "playpause");
  dict_write_tuplet(iter, &value);

  app_message_outbox_send();
}

static void up_click_handler(ClickRecognizerRef recognizer, void *context) {
  DictionaryIterator *iter;
  app_message_outbox_begin(&iter);

  Tuplet value = TupletCString(KEY_ACTION, "previous");
  dict_write_tuplet(iter, &value);

  app_message_outbox_send();
}

static void down_click_handler(ClickRecognizerRef recognizer, void *context) {
  DictionaryIterator *iter;
  app_message_outbox_begin(&iter);

  Tuplet value = TupletCString(KEY_ACTION, "next");
  dict_write_tuplet(iter, &value);

  app_message_outbox_send();
}

static void down_long_click_handler(ClickRecognizerRef recognizer, void *context) {
  DictionaryIterator *iter;
  app_message_outbox_begin(&iter);

  Tuplet value = TupletCString(KEY_ACTION, "groupVolume/-1");
  dict_write_tuplet(iter, &value);

  app_message_outbox_send();
}

static void up_long_click_handler(ClickRecognizerRef recognizer, void *context) {
  DictionaryIterator *iter;
  app_message_outbox_begin(&iter);

  Tuplet value = TupletCString(KEY_ACTION, "groupVolume/+1");
  dict_write_tuplet(iter, &value);

  app_message_outbox_send();
}

static void select_long_click_handler(ClickRecognizerRef recognizer, void *context) {
  DictionaryIterator *iter;
  app_message_outbox_begin(&iter);

  Tuplet value = TupletCString(KEY_ACTION, "pause");
  dict_write_tuplet(iter, &value);

  app_message_outbox_send();
}

static void click_config_provider(void *context) {
  window_single_click_subscribe(BUTTON_ID_SELECT, select_click_handler);
  window_single_click_subscribe(BUTTON_ID_UP, up_long_click_handler);
  window_single_click_subscribe(BUTTON_ID_DOWN, down_long_click_handler);
  window_long_click_subscribe(BUTTON_ID_UP, 700, up_click_handler, NULL);
  window_long_click_subscribe(BUTTON_ID_SELECT, 700, select_long_click_handler, NULL);
  window_long_click_subscribe(BUTTON_ID_DOWN, 700, down_click_handler, NULL);
}

static void window_load(Window *window) {
  Layer *window_layer = window_get_root_layer(window);
  GRect bounds = layer_get_bounds(window_layer);

  if(persist_exists(99))
  {
    int i_start = 0;
    int len = persist_read_int(99);
    uint8_t byte_array[256];
    while(persist_exists(100+i_start))
    {
      if(i_start+len > (IMAGE_SIZE*IMAGE_SIZE/8))
        len = (IMAGE_SIZE*IMAGE_SIZE/8) - i_start;
      if (len <= 0) break;
      int l = persist_read_data(100+i_start, &byte_array[0], len);
      //app_log(APP_LOG_LEVEL_INFO,"",1, "READ! row:%i %i bytes of %i", i_start, l, len);

      for(int i = 0; i < len; i++)
        album_art_data[i_start+i] = byte_array[i];

      i_start += len;
    }
  }


  album_art_layer = bitmap_layer_create((GRect) { .origin = { (144-DISPLAY_SIZE)/2, 0 }, .size = { DISPLAY_SIZE, DISPLAY_SIZE } });
  bitmap_layer_set_bitmap(album_art_layer,&album_art_bitmap);
  layer_add_child(window_layer, bitmap_layer_get_layer(album_art_layer));

  artist_text_layer = text_layer_create((GRect) { .origin = { 1, 128 }, .size = { bounds.size.w-1, 30 } });
  text_layer_set_text(artist_text_layer, "");
  text_layer_set_text_alignment(artist_text_layer, GTextAlignmentCenter);
  layer_add_child(window_layer, text_layer_get_layer(artist_text_layer));
  text_layer_set_background_color(artist_text_layer, GColorClear);
  text_layer_set_text_color(artist_text_layer, GColorWhite);
  text_layer_set_font(artist_text_layer, fonts_get_system_font(FONT_KEY_ROBOTO_CONDENSED_21));

  title_text_layer = text_layer_create((GRect) { .origin = { 1, 149 }, .size = { bounds.size.w-1, 20 } });
  text_layer_set_text(title_text_layer, "loading ...");
  text_layer_set_text_alignment(title_text_layer, GTextAlignmentCenter);
  layer_add_child(window_layer, text_layer_get_layer(title_text_layer));
  text_layer_set_background_color(title_text_layer, GColorClear);
  text_layer_set_text_color(title_text_layer, GColorWhite);

  text_layer2 = text_layer_create((GRect) { .origin = { 1-2, -2+0 }, .size = { bounds.size.w, 60 } });
  text_layer_set_text(text_layer2, "00:00");
  text_layer_set_text_alignment(text_layer2, GTextAlignmentCenter);
  layer_add_child(window_layer, text_layer_get_layer(text_layer2));
  text_layer_set_background_color(text_layer2, GColorClear);
  text_layer_set_text_color(text_layer2, GColorBlack);

  text_layer3 = text_layer_create((GRect) { .origin = { -1-2, -4+0 }, .size = { bounds.size.w, 60 } });
  text_layer_set_text(text_layer3, "00:00");
  text_layer_set_text_alignment(text_layer3, GTextAlignmentCenter);
  layer_add_child(window_layer, text_layer_get_layer(text_layer3));
  text_layer_set_background_color(text_layer3, GColorClear);
  text_layer_set_text_color(text_layer3, GColorBlack);

  text_layer4 = text_layer_create((GRect) { .origin = { -1-2, -2+0 }, .size = { bounds.size.w, 60 } });
  text_layer_set_text(text_layer4, "00:00");
  text_layer_set_text_alignment(text_layer4, GTextAlignmentCenter);
  layer_add_child(window_layer, text_layer_get_layer(text_layer4));
  text_layer_set_background_color(text_layer4, GColorClear);
  text_layer_set_text_color(text_layer4, GColorBlack);



  text_layer = text_layer_create((GRect) { .origin = { 0-2, -3+0 }, .size = { bounds.size.w, 60 } });
  text_layer_set_text(text_layer, "00:00");
  text_layer_set_text_alignment(text_layer, GTextAlignmentCenter);
  layer_add_child(window_layer, text_layer_get_layer(text_layer));
  text_layer_set_background_color(text_layer, GColorClear);
  text_layer_set_text_color(text_layer, GColorWhite);

  progress_layer = inverter_layer_create((GRect) { .origin = { 0, 0 }, .size = { bounds.size.w / 2, 50 } });
  layer_add_child(window_layer, inverter_layer_get_layer(progress_layer));
  update_progress();

  text_layer_set_font(text_layer, fonts_get_system_font(FONT_KEY_ROBOTO_BOLD_SUBSET_49));
  text_layer_set_font(text_layer2, fonts_get_system_font(FONT_KEY_ROBOTO_BOLD_SUBSET_49));
  text_layer_set_font(text_layer3, fonts_get_system_font(FONT_KEY_ROBOTO_BOLD_SUBSET_49));
  text_layer_set_font(text_layer4, fonts_get_system_font(FONT_KEY_ROBOTO_BOLD_SUBSET_49));

  if(persist_exists(96))
  {
    if(persist_read_int(96) == 1) text_layer_set_font(text_layer, fonts_get_system_font(FONT_KEY_ROBOTO_CONDENSED_21));
  }

  if(persist_exists(97))
  {
    static char buffer[64];
    persist_read_string(97,buffer,64);
    text_layer_set_text(artist_text_layer, buffer);
  }
  if(persist_exists(98))
  {
    static char buffer[64];
    persist_read_string(98,buffer,64);
    text_layer_set_text(title_text_layer, buffer);
  }

  time_t now = time(NULL);
  struct tm *tick_time = localtime(&now);
  display_time(tick_time);
}

static void window_unload(Window *window) {
  text_layer_destroy(text_layer);
  text_layer_destroy(artist_text_layer);
  text_layer_destroy(title_text_layer);
  //bitmap_layer_destroy(album_art_layer);
}

static void init(void) {

  app_message_register_inbox_received(in_received_handler);
  app_message_register_inbox_dropped(in_dropped_handler);
  app_message_register_outbox_sent(out_sent_handler);
  app_message_register_outbox_failed(out_failed_handler);

  //accel_tap_service_subscribe(&accel_tap_handler);
  //accel_tap_service_unsubscribe();

  tick_timer_service_subscribe(MINUTE_UNIT, handle_minute_tick);
  tick_timer_service_subscribe(SECOND_UNIT, handle_second_tick);

  const uint32_t inbound_size = 256;
  const uint32_t outbound_size = 64;
  app_message_open(inbound_size, outbound_size);

  window = window_create();
  //window_set_click_config_provider(window, click_config_provider);
  window_set_window_handlers(window, (WindowHandlers) {
    .load = window_load,
    .unload = window_unload,
  });
  window_set_fullscreen(window, true);
  window_set_status_bar_icon(window, gbitmap_create_with_resource(RESOURCE_ID_TINY_LASTFM));
  window_set_background_color(window, GColorBlack);
  const bool animated = true;
  window_stack_push(window, animated);
}

static void deinit(void) {
  window_destroy(window);
}

int main(void) {
  init();

  APP_LOG(APP_LOG_LEVEL_DEBUG, "Done initializing, pushed window: %p", window);

  app_event_loop();
  deinit();
}
