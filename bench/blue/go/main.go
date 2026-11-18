// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 GibblyGobbly
//
// The programs of bench/blue in Go, for compare.sh: <name> <the arguments of the Zue program>.
package main

import (
	"fmt"
	"os"
	"runtime"
	"strconv"
	"time"
)

func arg(i int) int { v, _ := strconv.Atoi(os.Args[i]); return v }

//go:noinline
func fib(n int) int {
	if n < 2 {
		return n
	}
	return fib(n-1) + fib(n-2)
}

func main() {
	t0 := time.Now()
	switch os.Args[1] {
	case "spawn_wait":
		n := arg(2)
		sum := 0
		for done := 0; done < n; done += 1000 {
			ts := make([]chan int, 0, 1000)
			for i := 0; i < 1000; i++ {
				c := make(chan int, 1)
				go func(i int) { c <- i + 1 }(i)
				ts = append(ts, c)
			}
			for _, c := range ts {
				sum += <-c
			}
		}
		fmt.Println("spawn_wait", n, sum, time.Since(t0))
	case "ping_pong":
		n := arg(2)
		a, b := make(chan int), make(chan int)
		go func() {
			for i := 0; i < n; i++ {
				b <- (<-a) + 1
			}
		}()
		s := 0
		for i := 0; i < n; i++ {
			a <- i
			s += <-b
		}
		fmt.Println("ping_pong", n, s, time.Since(t0))
	case "ring":
		k, hops := arg(2), arg(3)
		chans := make([]chan int, k+1)
		for i := range chans {
			chans[i] = make(chan int)
		}
		for i := 0; i < k; i++ {
			go func(in, out chan int) {
				for {
					v := <-in
					out <- v - 1
					if v <= 0 {
						return
					}
				}
			}(chans[i], chans[i+1])
		}
		t0 = time.Now()
		v, laps := hops, 0
		for v > 0 {
			chans[0] <- v
			v = <-chans[k]
			laps++
		}
		fmt.Println("ring", k, hops, laps, time.Since(t0))
	case "cpu_bound":
		k, n := arg(2), arg(3)
		cs := make([]chan int, k)
		for i := range cs {
			cs[i] = make(chan int, 1)
			go func(c chan int) { c <- fib(n) }(cs[i])
		}
		s := 0
		for _, c := range cs {
			s += <-c
		}
		fmt.Println("cpu", k, n, s, time.Since(t0))
	case "producers_consumers":
		k, n := arg(2), arg(3)
		ch := make(chan int, 128)
		res := make(chan int, 2*k)
		for i := 0; i < k; i++ {
			go func() {
				for i := 0; i < n; i++ {
					ch <- i
				}
				res <- n
			}()
			go func() {
				s := 0
				for i := 0; i < n; i++ {
					s += <-ch
				}
				res <- s
			}()
		}
		s := 0
		for i := 0; i < 2*k; i++ {
			s += <-res
		}
		fmt.Println("producers_consumers", k, n, s, time.Since(t0))
	case "uneven_load":
		uneven(arg(2))
	case "parked":
		n := arg(2)
		ch := make(chan int)
		res := make(chan int, n)
		for i := 0; i < n; i++ {
			go func() { res <- <-ch }()
		}
		t1 := time.Since(t0)
		for i := 0; i < n; i++ {
			ch <- i
		}
		s := 0
		for i := 0; i < n; i++ {
			s += <-res
		}
		fmt.Println("parked", n, s, "spawn_wait", t1, "total", time.Since(t0))
	}
}

func uneven(heavy int) {
	chans := make([]chan int, 256)
	res := make([]chan int, 256)
	for i := range chans {
		chans[i] = make(chan int, 1)
		res[i] = make(chan int, 1)
		go func(in, out chan int) { out <- fib(<-in) }(chans[i], res[i])
	}
	for i := 0; i < 2000; i++ {
		runtime.Gosched()
	}
	t0 := time.Now()
	for i := 0; i < 256; i++ {
		if (i*37)%256 < 16 {
			chans[i] <- heavy
		} else {
			chans[i] <- 1
		}
	}
	s := 0
	for _, c := range res {
		s += <-c
	}
	fmt.Println("uneven", s, time.Since(t0))
}
