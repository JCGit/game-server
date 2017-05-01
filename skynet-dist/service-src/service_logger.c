#include "skynet.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <errno.h>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <assert.h>
#include <libgen.h>
// 日志文件大小限制
#define LOG_MAX_SIZE 400*1024*1024
#define LOG_MAX_INDEX 100

struct logger {
    FILE * handle;
    int close;
    char log_dir[64];
    char log_prefix[20];
    int writen_bytes;
    time_t log_create_time;
};

int update_file_name(struct logger * inst);

struct logger *
logger_create(void) {
    struct logger * inst = skynet_malloc(sizeof(*inst));
    inst->handle = NULL;
    inst->close = 0;
    inst->writen_bytes = 0;
    return inst;
}

int sameday(time_t t1, time_t  t2)
{
    return (t1 + 8 * 3600) / 86400 == (t2 + 8 * 3600) / 86400 ? 1 : 0;
}

int create_log_dir(char* dir_name)
{
    if (access(dir_name, F_OK) != 0) {
        int saved_errno = errno;
        if (ENOENT == saved_errno)
        {
          if (mkdir(dir_name, 0755) == -1)
          {
              saved_errno = errno;
              fprintf(stderr, "mkdir error: %d\n", saved_errno);
              return -1;
          }
        }
        else
        {
            fprintf(stderr, "opendir error: %d\n", saved_errno);
            return -1;
        }
    }
    return 0;
}

void
logger_release(struct logger * inst) {
    if (inst->close) {
        fclose(inst->handle);
    }
    skynet_free(inst);
}

static int
logger_cb(struct skynet_context * context, void *ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
    struct logger * inst = ud;
    switch (type) {
        case PTYPE_SYSTEM:
            update_file_name(inst);
            // w to a?  why?
            /*
            if (inst->filename) {
                inst->handle = freopen(inst->filename, "a", inst->handle);
            }*/
            break;
        case PTYPE_TEXT:
            update_file_name(inst);
            size_t len = 0;
            len = fprintf(inst->handle, "[:%08x] ", source);
            fwrite(msg, sz , 1, inst->handle);
            fprintf(inst->handle, "\n");
            fflush(inst->handle);
            inst->writen_bytes = inst->writen_bytes + len + sz + 1;
            break;
    }
    return 0;
}

//一般情况下当天的日志不会超过LOG_MAX_INDEX个
int rename_file(struct logger* inst, char*name){
  int i = 0;
  char filename[512];
  char curname[512];
  while(i < LOG_MAX_INDEX){
      if (i == 0){
          snprintf(filename, sizeof(filename), "%s/%s.log", inst->log_dir, name);
          i++;
      }else{
          snprintf(filename, sizeof(filename), "%s/%s-%d.log", inst->log_dir, name, i++);
      }
      if(access(filename, F_OK) == 0){
          continue;
      }else{
          break;
      }
  }

  if ((i-1) != 0){
      snprintf(curname, sizeof(curname), "%s/%s.log", inst->log_dir, name);
      if (rename(curname, filename) != 0 ){
          int saved_errno = errno;
          fprintf(stderr, "rename_file error: %d from : %s to : %s\n", saved_errno, curname, filename);
      }
  }
  return 0;
}

int open_file(struct logger * inst)
{
    char timebuf[64];
    char filename[512];
    char prefix[256];
    struct tm tm;
    time_t now = time(NULL);
    localtime_r(&now, &tm);
    strftime(timebuf, sizeof(timebuf), "%Y%m%d", &tm);

    create_log_dir(inst->log_dir);

    snprintf(prefix, sizeof(prefix), "%s.%s", inst->log_prefix, timebuf);
    rename_file(inst, prefix);

    snprintf(filename, sizeof(filename), "%s/%s.%s.log", inst->log_dir, inst->log_prefix, timebuf);
    inst->handle = fopen(filename, "a+");
    if (inst->handle == NULL)
    {
      int saved_errno = errno;
      fprintf(stderr, "open file error: %d\n", saved_errno);
      fprintf(stderr, filename);
      inst->handle = stdout;
    }

    return 0;
}

int update_file_name(struct logger * inst)
{
    int need_create = 1;

    time_t now = time(NULL);
    struct tm* now_tm = localtime(&now);
    time_t now_local = mktime(now_tm);

    // 首次打开文件
    if(NULL == inst->handle) {
        inst->log_create_time = now_local;
    }
    // 日期不同了
    else if(sameday(now_local, inst->log_create_time) == 0) {
        inst->log_create_time = now_local;
    }
    // 写的量超过了上限
    else if(LOG_MAX_SIZE < inst->writen_bytes) {
        inst->writen_bytes = 0;
        inst->log_create_time = now_local;
    }
    else{
        need_create = 0;
    }

    if(0 == need_create){
        return 0;
    }

    if (stdout == inst->handle) {
      return 0;
    }

    if(inst->handle != NULL)
    {
        fflush(inst->handle);
        fclose(inst->handle);
    }
    open_file(inst);
    return 0;
}

int
logger_init(struct logger * inst, struct skynet_context *ctx, const char * parm) {
    char tmp[256];
    memset(tmp, 0, 256);
    memset(inst->log_dir, 0, sizeof(inst->log_dir));
    memset(inst->log_prefix, 0, sizeof(inst->log_prefix));
    if (parm){
        strncpy(tmp, parm, 256);
        char *dir = dirname((char*)tmp);
        char *base = strrchr(parm, '/');
        char *dot = strrchr(parm, '.');
        if (dot > base){
           strncpy(inst->log_prefix, base+1, dot - base - 1);
        }else{
           strncpy(inst->log_prefix, base+1, strlen(base)-1);
        }
        strncpy(inst->log_dir, dir, strlen(dir));
        update_file_name(inst);
    }
    else
    {
        inst->handle = stdout;
    }

    if (inst->handle) {
        skynet_callback(ctx, inst, logger_cb);
        skynet_command(ctx, "REG", ".logger");
        return 0;
    }
    return 1;
}

