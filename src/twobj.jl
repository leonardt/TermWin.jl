# default behavior, dummy behavior, and convenient functions for all widgets

widgetStaggerPosx = 0
widgetStaggerPosy = 0

function configure_newwinpanel!( obj::TwObj )
    obj.window = newwin( obj.height,obj.width,obj.ypos,obj.xpos )
    obj.panel = new_panel( obj.window )
    cbreak()
    noecho()
    keypad( obj.window, true )
    nodelay( obj.window, true )
    wtimeout( obj.window, 100 )
    curs_set( 0 )
end

function alignxy!( o::TwObj, h::Real, w::Real, x::Any, y::Any;
        relative::Bool=false, # if true, o.xpos = parent.x + x
        parent = o.screen.value )
    global widgetStaggerPosx, widgetStaggerPosy
    if typeof( parent ) <: TwScreen
        parentwin = parent.window
        ( parbegy, parbegx ) = getwinbegyx( parentwin )
        ( parmaxy, parmaxx ) = getwinmaxyx( parentwin )
    else
        tmppar = parent
        while( typeof( tmppar.window) <: TwWindow )
            tmppar = tmppar.window.parent.value.window
        end
        parmaxy = tmppar.height
        parmaxx = tmppar.width
        log( "parmaxy=" * string(parmaxy) * "parmaxx=" * string( parmaxx ) )
        parbegx = parbegy = 0
    end
    if typeof( h ) <: Integer
        o.height = min( h, parmaxy )
    elseif typeof( h ) <: FloatingPoint && 0.0 < h <= 1.0
        o.height = int( parmaxy * h )
        if o.height == 0
            throw( "height is too small")
        end
    else
        throw( "Illegal ysize " * string( h ) )
    end

    if typeof( w ) <: Integer
        o.width = min( w, parmaxx )
    elseif typeof( w ) <: FloatingPoint && 0.0 < w <= 1.0
        o.width = int( parmaxx * w )
        if o.width == 0
            throw( "width is too small")
        end
    else
        throw( "Illegal xsize " * string( w ) )
    end

    if relative
        if typeof( x ) <: Integer && typeof( y ) <: Integer
            (begy, begx) = getwinbegyx( o.window )
            xpos = x+begx
            ypos = y+begy
        else
            throw( "Illegal relative position" )
        end
    else
        xpos = x
        ypos = y
    end

    gapx = max( 0, parmaxx - o.width )
    gapy = max( 0, parmaxy - o.height )
    lastx = parbegx + gapx
    lasty = parbegy + gapy
    if x == :left
        xpos = parbegx
    elseif x == :right
        xpos = parbegx + gapx
    elseif x == :center
        xpos = int( parbegx + gapx / 2 )
    elseif x == :random
        xpos = int( parbegx + gapx * rand() )
    elseif x == :staggered
        if widgetStaggerPosx > gapx
            widgetStaggerPosx = 0
        end
        xpos = parbegx + widgetStaggerPosx
        widgetStaggerPosx += 4
    elseif typeof( x ) <: FloatingPoint && 0.0 <= x <= 1.0
        xpos = int( parbegx + gapx * x )
    end
    xpos = max( min( xpos, lastx ), parbegx )

    if y == :top
        ypos = parbegy
    elseif y == :bottom
        ypos = parbegy + gapy
    elseif y == :center
        ypos = int( parbegy + gapy / 2 )
    elseif y == :random
        ypos = int( parbegy + gapy * rand() )
    elseif y == :staggered
        if widgetStaggerPosy > gapy
            widgetStaggerPosy = 0
        end
        ypos = parbegy + widgetStaggerPosy
        widgetStaggerPosy += 2
    elseif typeof( y ) <: FloatingPoint  && 0.0 <= y <= 1.0
        ypos = int( parbegy + gapy * y )
    end
    ypos = max( min( ypos, lasty ), parbegy )
    o.xpos = xpos
    o.ypos = ypos
end

#=
function unsetFocus( o::TwObj )
    curs_set( 0 )
    obj.hasfocus = false
    unfocus(obj)
end

function setFocus( o::TwObj )
    obj.hasfocus = true
    focus(obj)
    curs_set(1)
end

function switchFocus( newobj, oldobj )
    if oldobj != newobj
        unsetFocus( oldobj )
        setFocus( newobj )
    end
end
=#

# a general blocking API to make a widget a dialogue
function activateTwObj( o::TwObj, tokens::Any=nothing )
    if objtype(o) == :Screen
        return activateTwScreen( o, tokens )
    end
    maxy, maxx = getwinmaxyx( o.window )
    werase( o.window )
    mvwprintw( o.window, maxy>>1, maxx>>1, "%s", "..." )
    wrefresh( o.window )

    draw(o)
    if tokens == nothing #just wait for input
        while true
            update_panels()
            doupdate()
            token = readtoken( o.window )
            status = inject( o, token ) # note that it could be :nochar
            if status == :exit_ok
                return o.value
            elseif status == :exit_nothing # most likely a cancel
                return nothing
            end # default is to continue
        end
    else
        for token in tokens
            update_panels()
            doupdate()
            status = inject( o, token )
            if status == :exit_ok
                return o.value
            elseif status == :exit_nothing # most likely a cancel
                return nothing
            end
        end
        # exhausted all the tokens, no obvious response
        unregisterTwObj( o.screen.value, o )
        return nothing
    end
end

function inject( o::TwObj, k::Any )
    @lintpragma( "Ignore unused o")
    if k== :esc
        return :exit_nothing
    else
        return :pass
    end
end

erase( o::TwObj ) = werase( o.window )

function move( o::TwObj, x, y, relative::Bool, refresh::Bool=false )
    begy, begx = getwinbegyx( o.window )
    alignxy!( o, o.height, o.width, x, y, relative=relative )

    xdiff = o.xpos - begx
    ydiff = o.ypos - begy

    if xdiff == 0 && ydiff == 0
        return
    end
    move_panel( o.panel, o.ypos, o.xpos )
    touchwin( o.screen.value )
    if refresh
        draw(o)
    end
end

function focus( o::TwObj )
    @lintpragma( "Ignore unused o" )
end
function unfocus( o::TwObj )
    @lintpragma( "Ignore unused o" )
end
refresh( o::TwObj ) = (erase(o);draw(o))
