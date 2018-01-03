---
title: "Lightning fast serialization of datasets using the fst package"
author: "Mark Klik"
date: '2017-12-16'
coverImage: //d1u9biwaxjngwg.cloudfront.net/welcome-to-tranquilpeak/city.jpg
editor_options:
  chunk_output_type: console
metaAlignment: center
slug: fst_0.8.0
tags:
- compression
- serialization
- fst package
- hashing
- benchmark
thumbnailImage: http://res.cloudinary.com/dbji2rjvf/image/upload/v1512862863/parallel2_i7p1pu.png
thumbnailImagePosition: left
categories:
- R
- compression
- serialization
- hashing
- benchmark
- fst package
---

Version 0.8.0 of R's _fst_ package has been released to CRAN. The package is now multi-threaded allowing for even faster serialization of data frames to disk.

<!--more-->

This post covers some of the enhancements that have been made to _fst_ in the latest release and measures the performance against the serialization methods offered by packages _feather_ and by _base R_ itself. A parallel is drawn with the multi-threading enhancements recently added to _data.table_'s methods _fread_ and _fwrite_ for working with  _csv_ files. Also, some words on how and when to best use the _fst_ binary format to benefit your workflow and speed up your calculations (and when not).


<!-- toc -->

# Introduction

For a few years now, solid state disks (SSD's) have been getting larger in capacity, faster and much cheaper. It's not uncommon to find a high-performance SSD with speeds of up to multiple GB/s in a medium-end laptop. At the same time, the number of cores per CPU keeps growing. The combination of these two trends are opening up the way for data science to work on large data sets using a very modest computer setup.

The _fst_ package aims to provide a solution for storing data frames on modern SSD's at the highest possible speed. It uses multiple threads and compression to achieve speeds that can top even the fastest consumer SSD's that are currently available. At the same time, the _fst_ file format was designed as a random access format from the ground up. This offers a lot of flexibility and allows reading subsets of data frames (both columns and rows) at high speeds.

Below you can see just how fast _fst_ is. The benchmark was performed on a laptop with a mid range CPU (i7 4710HQ @2.5 GHz) and a reasonably fast (NVME) SSD (M.2 Samsung SM951). The datasets used for measurement were generated on the fly and consists of various column types (as defined below). The number of threads (were appropriate) was set to 8.

<br>


|Method        |Format  |Time (sec) |Size (MB) |File Size (MB) |Speed (MB/s) |N       |
|:-------------|:-------|:----------|:---------|:--------------|:------------|:-------|
|readRDS       |bin     |1.57       |1000      |1000           |633          |112     |
|saveRDS       |bin     |2.04       |1000      |1000           |489          |112     |
|read_feather  |bin     |3.95       |1000      |812            |253          |112     |
|write_feather |bin     |1.82       |1000      |812            |549          |112     |
|**read_fst**  |**bin** |**0.45**   |**1000**  |**303**        |**2216**     |**142** |
|**write_fst** |**bin** |**0.28**   |**1000**  |**303**        |**3559**     |**142** |
_Table 1: read and write performance of fst, feather and baseR binary formats_

The table compares method _write\_fst_ to it's counterparts _write\_feather_ and _saveRDS_. Method _read\_fst_ is compared to it's counterparts _read\_feather_ and _readRDS_. For _saveRDS_, the uncompressed mode was selected because the compressed mode is very slow (a few MB/s only).

As can be seen, a write speed of more than 3.5 GB/s was measured for _write\_fst_. That speed is even higher than the speed reported in the drive's specifications! 

After introducing some of the basic features of _fst_, we will get back to these benchmarks and take a look at how the package uses a combination of multi-threading and compression to effectively boost the performance of data frame serialization.

# Put _fst_ to work

The package interface for serialization of data frames is quite straightforward. To write a data frame to disk:


```r
library(fst)

write_fst(df, "sampleset.fst")  # write using default compression
```

This writes data frame _df_ to a _fst_ file using the default compression setting of 50 percent. To retrieve the stored data:


```r
df_read <- read_fst("sampleset.fst")  # read a fst file
```

That's all you need for basic functionality!

In addition, the _fst_ file format was especially designed to provide random access to the stored data. To retrieve a subset of your data you can use:


```r
df_read <- read_fst("sampleset.fst", c("A", "B"), 1000, 2000)
```



This reads rows 1000 to 2000 from columns _A_ and _B_ without actually touching any other data in the stored file. That means that a subset can be read from file **without reading the complete file first**. This is different from, say, _readRDS_ or _read\_feather_ where you have to read the complete file or column before you can make a subset.

This 'on-disk subsetting' takes less memory, because memory is only allocated for columns and rows that are actually read from disk. So even with a _fst_ file that is much larger than the amount of RAM in your computer, you can still read a subset without running out of memory!

The graph below depicts the relation between the read time and the amount of rows selected from a 50 million row _fst_ file. As you can see, the average read time grows with the amount of rows selected. Reading all 50 million rows takes around 0.45 seconds, the value reported in the table in the introduction.

<img src="/img/fst_0.8.0/img/fig-unnamed-chunk-8-1.png" title="plot of chunk unnamed-chunk-8" alt="plot of chunk unnamed-chunk-8" width="50%" />

# Some basic speed measurements

The read and write speed of _fst_ depends on the compression setting and the number of threads used. To get an idea about these dependencies we generate a dataset containing various column types and do some speed measurements:


```r
nr_of_rows <- 5e7  # use 50 million rows

df <- 
    data.frame(

      # Logical column with mostly TRUE's, some FALSE's and few NA's
      Logical = sample(c(TRUE, FALSE, NA), prob = c(0.85, 0.1, 0.05), nr_of_rows, replace = TRUE),
  
      # Integer column with values between 1 and 100
      Integer = sample(1L:100L, nr_of_rows, replace = TRUE),
  
      # Real column simulating 'prices'
      Real = sample(sample(1:10000, 20) / 100, nr_of_rows, replace = TRUE),
  
      # Factor column with US cities
      Factor = as.factor(sample(labels(UScitiesD), nr_of_rows, replace = TRUE))
  )
```

This dataset was also used to obtain the benchmark results reported above. To get accurate timings for writing to disk we use the _microbenchmark_ package




```r
library(microbenchmark)

# perform a single measurement only to avoid disk caching
write_speed <- microbenchmark(
  write_fst(df, "sampleset.fst"),
  times = 1
)

# speed in GB/s
as.numeric(object.size(df)) / write_speed$time
```


```
## [1] 3.55976
```

So how can the measured write speed (about 3.5 GB/s) be so much higher than the maximum write speed of the SSD used (about 1.2 GB/s)? The explanation is that the actual amount of bytes that where pushed to the SSD is lower than the in-memory size of the data frame (and **less data == more speed**):


```r
# compression ratio:
as.numeric(file.size("sampleset.fst") / object.size(df))
```

```
## [1] 0.2996764
```

So the file size is about 29 percent of the original data frame size. This reduced file size is the result of using a default compression setting of 50 percent. Apart from the resulting speed increase, smaller files are also attractive from a storage point of view.


# Multi-threading

Like _data.table_, the _fst_ package uses multiple threads to read and write data. So how does the number of threads affect the performance? You can tune multithreading with:


```r
threads_fst(8)  # allow fst to use 8 threads
```

With more threads _fst_ can do more background processing such as compression. Obviously, setting more threads than there are (logical) cores available in your computer won't help you (in most cases).

The graph below shows measurements of the read- and write speeds for various 'thread settings' and number of rows. Sample sizes of 10 million and 50 million rows were used.

![plot of chunk unnamed-chunk-15](/img/fst_0.8.0/img/fig-unnamed-chunk-15-1.png)



The effects of multi-threading are quite obvious and _fst_ does well in both reading and writing (note that the bar corresponding to _Threads == 1_ is basically _fst_ before version 0.8.0). A top write speed of 3.6 GB/s was measured using 7 threads. My laptop only has 4 physical cores, but increasing beyond 4 threads still increases performance (apparently hyperthreading does work in some cases :-)).

> The measured read speeds are lower than the write speeds although the SSD has a higher read throughput according to the specifications. This probably means that there is room for some more improvements on the read speeds when the code is further optimized.

The way _fst_ uses multiple threads to do background processing is similar to how the _data.table_ packages employs multiple threads to parse and write _csv_ files:


```
## Error: <text>:4:1: unexpected '['
## 3: 
## 4: [
##    ^
```


Next to _fst_ there is another clear winner in this graph, and that is the _data.table_ package with it's methods _fwrite_ and _fread_. It stands out because the _csv_ file  format is not a binary format but a human-readable text format! Normally, binary formats would be much faster than the _csv_ format, because _csv_ takes more space on disk, is row based, uncompressed and needs to be parsed into a computer-native format to have any meaning. So any serializer that's working on _csv_ has an enormous disadvantage as compared to binary formats. Yet, the results show that _data.table_ is on par with binary formats and when more threads are used, it can even be faster. This is all due to the excellent work of the people working on the _data.table_ package. They recently created parallel implementations of _fwrite_ and _fread_ and they are very fast, an impressive piece of work!

# How compression helps to increase performance

The maximum read- and write speeds of your computer's (solid state-) disk are a given. Any read or write operations to and from disk are bound by those maximum speeds, there's not much you can do about that (except buy a faster disk).

However, the amount of data that goes back and forth between the disk and your computer memory can be reduced by using compression. If you compress your data with, let's say, a factor of two, the disk will probably spent about half the time on reading or writing that data (**less data == more speed**). The downside is that the compression itself will also take CPU time, so there is a trade-off there that depends on the speed of the disk and the CPU speed.

How does that work? Suppose a disk has an extremely high speed, then any amount of compression will lower the total speed of writing data to that disk. On the other hand, when the disk has a very low speed (say a network drive), any amount of compression would actually increase the total speed. Most setups will have maximum performance somewhere in between.

To shift the balance, the _fst_ package uses multithreading to compress data 'in the background', so while the disk is busy writing data. Using that setup, it's possible to saturate your disk and still compress data, effectively increasing the observed write (and read) speed. The figure below shows how compression impacts the performance of reading and writing data to disk.

![plot of chunk unnamed-chunk-18](/img/fst_0.8.0/img/fig-unnamed-chunk-18-1.png)

These measurements were performed on a Xeon E5 CPU machine (@2.5GHz) that has 20 physical cores. With more cores, it's easier to see the scaling effects. The horizontal groups in the figure represent the different amount of threads used (4, 8, 10 and 20). Vertically we have the read and write speeds. The colors represent various compression settings in the range of 0 to 100 (so not the number of threads like in the previous graph). Compression helps a lot to increase the write speed. If enough cores are used, the background compression can keep up with the SSD and the total write speed will increase accordingly (**less data == more speed**). The same could be expected to be true for the read speed. The effects seem to be minimal however and some more thinking is required to bring the read speed at the same level as the write speed (perhaps we need parallel file connections, larger read blocks or different multi-threading logic? [ideas are very welcome](https://github.com/fstpackage/fst/issues) :-)).

# Per-column compression optimalization

The _fst_ package uses the excellent [LZ4](http://lz4.github.io/lz4/) compressor for high speed compression at lower ratio's and the [ZSTD](http://facebook.github.io/zstd/) compressor for medium speed compression at higher ratio's. Compression is done on small (16kB) blocks of data, which allows for (almost) random access of data. Each column uses it's own compression scheme and different compressors can be mixed within a single column. This flexible setup allows for better optimized and faster compression of data.

> Note: there is still much work to be done to further optimize these compression schemes. The current version of the _fst_ package is using 'best (first) guess schemes'. Following more elaborate benchmarks in the future, these schemes will be fine-tuned for better performance and new compressors could also be added (such as dictionary based compressors optimized for text or bit-packing compressors for integers).

All compression settings in _fst_ are set as a value between 0 and 100 ('a percentage'). That percentage is translated into a mix of compression settings for each (16kB) data block. This mix is optimized (or will be :-)) for that particular data type. For example, at a compression setting of 30, data blocks in an integer column are a mix of 40 percent uncompressed blocks and 60 percent blocks compressed with LZ4 + a byte shuffle. The byte shuffle works because we are dealing with an integer column. So we use information about the specific column _type_ to enhance the compression. This is a unique feature of _fst_ that has a huge positive impact on performance.


# More new features in fst v0.8.0

## Separate core library

With this new release, the core C++ code of _fst_ is completely separated from the _fst_ 'R API' (the C++ core library is now called [_fstlib_](https://github.com/fstpackage/fstlib)). Having a separate C++ library opens up the way for other languages to implement the _fst_ format (e.g. Python, Julia, C++).

## Multi-threaded access to LZ4 and ZSTD compressors

The LZ4 and ZSTD compressors can now be used directly using methods _compress\_fst_ and _decompress\_fst_. For example, to compress the csv file  _survey\_results\_public.csv_ [from Kaggle](https://www.kaggle.com/stackoverflow/so-survey-2017) (with data about StackOverflow users), you can use:




```r
# file downloaded from https://www.kaggle.com/stackoverflow/so-survey-2017
sample_file <- "large/survey_results_public.csv"
raw_vec <- readBin(sample_file, "raw", file.size(sample_file))  # read byte contents 

# compress bytes with ZSTD
compressed_vec <- compress_fst(raw_vec, "ZSTD", 10)

length(compressed_vec) / length(raw_vec)  # compression ratio
```

```
## [1] 0.1194816
```

This compresses the contents of the _survey\_results\_public.csv_ file to about 12 percent of the original size. You can decompress again with:


```r
raw_vec_decompressed <- decompress_fst(compressed_vec)
```

What's special about the fst implementation is that it's a fully multi-threaded implementation of the underlying compression algorithms, boosting the compression and decompression speeds:





```r
# compress with LZ4 on maximum compression setting
compress_time <- microbenchmark(
  compress_fst(raw_vec, "ZSTD", 10),
  times = 10
)

# decompress again
decompress_time <- microbenchmark(
  decompress_fst(compressed_vec),
  times = 10
)

cat("Compress: ", 1e3 * as.numeric(object.size(raw_vec)) / median(compress_time$time),
    "Decompress: ", 1e3 * as.numeric(object.size(raw_vec)) / median(decompress_time$time))
```


```
## Compress:  1509.439 Decompress:  2908.441
```

The measurement was done using 8 threads. Just like with _write\_fst_, compression is done on multiple threads, but there is no optimization for specific types (because the raw input vector can contain any type of data).

## Multi-threaded hashing

The last feature that I would like to mention briefly is the multi-threaded hashing algorithm that has been added to fst v0.8.0:


```r
hash_fst(raw_vec)
```

```
## [1]  1853499107 -1914678989
```

The return value is a length two integer vector because the hashing algorithm is actually a 64-bit hashing algorithm. Based on the already fast [xxHash](http://cyan4973.github.io/xxHash/) algorithm, the speed of the multi-threaded hash implementation in _fst_ is pretty extreme:


```r
threads_fst(8)

hash_timing <- microbenchmark(
  hash_fst(raw_vec),
  times = 1000
)

# hashing speed (GB/s)
as.numeric(object.size(raw_vec)) / median(hash_timing$time)
```


```r
as.numeric(object.size(raw_vec)) / median(hash_timings$hash_timing$time)
```

```
## [1] 11.55543
```

That's a hashing speed of more than 11 GB/s !

# Format stable and backwards compatible

With CRAN release v0.8.0, the format is stable and backwards compatible. That means that all _fst_ files generated with _fst_ package v0.8.0 or later can be read by future versions of the package.

# Future plans

Many new features are planned for _fst_ thanks to a lot of requests and idea's from the community (much obliged!), a few examples:

* multi-threaded (de-)serialization of _character_ columns
* _data.table_ interface
* row bind data to an existing _fst_ file
* add columns to an existing _fst_ file
* on-disk filtering of data with small memory footprint
* hashing of data blocks for added security
* encryption
* fast sampling of a _fst_ file
* _dplyr_ interface

Thanks for making it to the end of my post (no small task) and for your interest in using _fst_!
